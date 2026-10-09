import 'package:llm_model_templates/src/stream/model_output.dart';
import 'package:llm_model_templates/src/stream/stream_chunk.dart';
import 'package:llm_model_templates/src/stream/stream_parser.dart';
import 'package:llm_model_templates/src/stream/stream_tokenizer.dart';
import 'package:llm_model_templates/src/stream/tool_call_extractor.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Configuration for the [UniversalStreamParser].
final class StreamParserConfig {
  StreamParserConfig({
    required this.toolCallExtractor,
    required this.tags,
    required this.supportsReasoning,
  });

  final ToolCallExtractor toolCallExtractor;

  /// Tag definitions for the stream tokenizer.
  final List<TagDefinition> tags;

  final bool supportsReasoning;
}

enum _ParserState { normal, reasoning, toolCall }

/// How the parser entered `_ParserState.toolCall`.
///
/// * [wrapper] — entered via an explicit `<tool_call>` (or equivalent)
///   opening tag. The corresponding closing tag is the terminator.
/// * [fallback] — entered via a bare `<function=…>` tag without a
///   surrounding wrapper (a known Qwen 3 Coder quirk). The matching
///   `</function>` is the terminator, and the matched tag strings are
///   preserved in the buffer so the extractor can still read the
///   function name.
enum _ToolEntry { wrapper, fallback }

/// Universal stream parser for all supported model families.
///
/// Each chunk is fed to the synchronous [StreamTokenizer], tokens are
/// classified through the state machine, and token counts are emitted after
/// text classification.
final class UniversalStreamParser implements StreamParser {
  UniversalStreamParser({required this.config});

  final StreamParserConfig config;

  @override
  StreamParserSession start({
    Set<String>? knownToolNames,
    bool answerPrefilled = false,
    bool reasoningPrefilled = false,
  }) {
    // This parser already starts in a plain-text state, so a prefilled answer
    // needs no special handling — the flag is accepted for interface
    // conformance only.
    return _UniversalStreamParserSession(
      config: config,
      knownToolNames: knownToolNames,
      reasoningPrefilled: reasoningPrefilled,
    );
  }
}

final class _UniversalStreamParserSession implements StreamParserSession {
  _UniversalStreamParserSession({
    required this.config,
    required this.knownToolNames,
    required bool reasoningPrefilled,
  }) : _state = reasoningPrefilled && config.supportsReasoning
           ? _ParserState.reasoning
           : _ParserState.normal;

  final StreamParserConfig config;
  final Set<String>? knownToolNames;
  late final StreamTokenizer tokenizer = StreamTokenizer(tags: config.tags);
  _ParserState _state;
  _ToolEntry? _toolEntry;
  var _toolBuffer = '';

  @override
  Iterable<ModelOutput> add(StreamChunk chunk) sync* {
    // Wrapper-less `<function=…>` tool calls are only honoured when the
    // caller has told us what tool names are in play for this turn —
    // otherwise a stray `<function=…>` in prose would be mis-parsed as
    // a tool call.
    final toolNames = knownToolNames;
    final fallbackToolsActive = toolNames != null && toolNames.isNotEmpty;

    // 1. Feed text to tokenizer synchronously → classified tokens.
    final tokens = chunk.text.isNotEmpty
        ? tokenizer.feed(chunk.text)
        : <StreamToken>[];

    // 2. Process tokens through the state machine.
    for (final token in tokens) {
      switch (_state) {
        case _ParserState.normal:
          switch (token.type) {
            case StreamTokenType.text:
              yield ModelTextDelta(token.text!);

            case StreamTokenType.thinkStart:
              if (config.supportsReasoning) {
                _state = _ParserState.reasoning;
              }

            case StreamTokenType.toolStart:
              if (token.tagText != null) {
                // Bare fallback entry (e.g. `<function=`). Only honour
                // when tools are registered; otherwise treat as text.
                if (fallbackToolsActive) {
                  _state = _ParserState.toolCall;
                  _toolEntry = _ToolEntry.fallback;
                  _toolBuffer = token.tagText!;
                } else {
                  yield ModelTextDelta(token.tagText!);
                }
              } else {
                _state = _ParserState.toolCall;
                _toolEntry = _ToolEntry.wrapper;
                _toolBuffer = '';
              }

            case StreamTokenType.toolEnd:
              // Stray closer in normal mode. If the tag should be
              // preserved, yield it as text; otherwise ignore.
              if (token.tagText != null) {
                yield ModelTextDelta(token.tagText!);
              }

            case StreamTokenType.thinkEnd:
              break; // Ignore unexpected closing tags in normal mode.
          }

        case _ParserState.reasoning:
          switch (token.type) {
            case StreamTokenType.text:
              yield ModelReasoningDelta(token.text!);
            case StreamTokenType.thinkEnd:
              _state = _ParserState.normal;
            case StreamTokenType.thinkStart:
            case StreamTokenType.toolStart:
            case StreamTokenType.toolEnd:
              break;
          }

        case _ParserState.toolCall:
          switch (token.type) {
            case StreamTokenType.text:
              _toolBuffer += token.text!;

            case StreamTokenType.toolStart:
              // Nested `<function=` inside an outer wrapper — keep
              // the literal so the extractor's regex can see it.
              // Tagless starts are defensively ignored (today's
              // behaviour).
              if (token.tagText != null) {
                _toolBuffer += token.tagText!;
              }

            case StreamTokenType.toolEnd:
              final closesFallback =
                  token.tagText != null && _toolEntry == _ToolEntry.fallback;
              final closesWrapper = token.tagText == null;
              if (token.tagText != null) {
                // `</function>`-style closer: always append to the
                // buffer so the extractor sees the closing tag.
                _toolBuffer += token.tagText!;
              }
              if (closesFallback || closesWrapper) {
                yield* _resolveToolCall(_toolBuffer);
                _state = _ParserState.normal;
                _toolEntry = null;
                _toolBuffer = '';
              }
            // Otherwise: inner `</function>` inside a wrapper —
            // already appended, stay in toolCall state waiting for
            // the real `</tool_call>` terminator.

            case StreamTokenType.thinkStart:
            case StreamTokenType.thinkEnd:
              break;
          }
      }
    }

    // 3. Emit token count AFTER text classification.
    if (chunk.tokenCountDelta > 0) {
      yield ModelTokensGenerated(chunk.tokenCountDelta);
    }
  }

  @override
  Iterable<ModelOutput> finish() sync* {
    // Flush tokenizer remainder.
    final remaining = tokenizer.flush();
    for (final token in remaining) {
      switch (_state) {
        case _ParserState.normal:
          if (token.type == StreamTokenType.text) {
            yield ModelTextDelta(token.text!);
          }
        case _ParserState.reasoning:
          if (token.type == StreamTokenType.text) {
            yield ModelReasoningDelta(token.text!);
          }
        case _ParserState.toolCall:
          if (token.type == StreamTokenType.text) {
            _toolBuffer += token.text!;
          }
      }
    }

    // Handle stream end.
    if (_state == _ParserState.toolCall && _toolBuffer.isNotEmpty) {
      // Model ended mid-tool-call (e.g. Mistral with no end tag, or
      // Qwen 3 Coder whose `</function>` got truncated). For fallback
      // entry we synthesise the closing tag so the XML extractor has
      // a complete function block to match.
      final bufferForExtract =
          _toolEntry == _ToolEntry.fallback &&
              !_toolBuffer.contains('</function>')
          ? '$_toolBuffer\n</function>'
          : _toolBuffer;
      yield* _resolveToolCall(bufferForExtract, flushText: _toolBuffer);
    }

    yield const ModelStepFinished(ModelStopReason.stop);
  }

  /// Resolves a completed tool-call buffer into outputs.
  Iterable<ModelOutput> _resolveToolCall(
    String buffer, {
    String? flushText,
  }) sync* {
    final parsed = config.toolCallExtractor.extract(buffer);
    if (_toolEntry == _ToolEntry.fallback) {
      final filtered = _filterCalls(parsed, knownToolNames);
      if (filtered.isNotEmpty) {
        for (final call in filtered) {
          yield ModelToolCallOutput(call);
        }
      } else {
        yield ModelTextDelta(flushText ?? buffer);
      }
      return;
    }
    if (parsed.isNotEmpty) {
      for (final call in parsed) {
        yield ModelToolCallOutput(call);
      }
      return;
    }
    final raw = flushText ?? buffer;
    if (raw.contains('{')) {
      yield ModelToolCallUnparsed(rawText: raw);
    } else if (raw.trim().isNotEmpty) {
      yield ModelTextDelta(raw);
    }
  }

  /// Keeps only tool calls whose name is registered.
  ///
  /// A null [knownToolNames] means the caller didn't express a
  /// whitelist (e.g. a parser that doesn't support it) — pass through
  /// unchanged. An explicit empty set means "no tools registered" and
  /// filters everything out.
  static List<ToolCall> _filterCalls(
    List<ToolCall> calls,
    Set<String>? knownToolNames,
  ) {
    if (knownToolNames == null) return calls;
    return calls.where((call) => knownToolNames.contains(call.name)).toList();
  }
}
