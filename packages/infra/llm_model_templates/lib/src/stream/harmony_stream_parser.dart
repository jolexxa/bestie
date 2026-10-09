import 'dart:convert';

import 'package:llm_model_templates/src/stream/model_output.dart';
import 'package:llm_model_templates/src/stream/stream_chunk.dart';
import 'package:llm_model_templates/src/stream/stream_parser.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Stream parser for OpenAI's Harmony format.
///
/// Harmony uses channel-based routing (`<|channel|>analysis|final|commentary`)
/// instead of XML tags. The `<|end|>` token is reused across all message types,
/// so we cannot use the generic `StreamTokenizer`. This parser implements its
/// own tag scanner with a state machine.
final class HarmonyStreamParser implements StreamParser {
  HarmonyStreamParser();

  int _toolCallIdCounter = 0;

  @override
  StreamParserSession start({
    Set<String>? knownToolNames,
    bool answerPrefilled = false,
    bool reasoningPrefilled = false,
  }) {
    // Harmony prompts never end inside an open analysis channel, so a
    // prefilled-reasoning start state does not apply here.
    return _HarmonyStreamParserSession(
      nextToolCallId: () => _toolCallIdCounter++,
      answerPrefilled: answerPrefilled,
    );
  }
}

final class _HarmonyStreamParserSession implements StreamParserSession {
  _HarmonyStreamParserSession({
    required int Function() nextToolCallId,
    required bool answerPrefilled,
  }) : _nextToolCallId = nextToolCallId,
       _state = answerPrefilled
           ? _HarmonyState.inFinal
           : _HarmonyState.awaitingDirective;

  final int Function() _nextToolCallId;
  _HarmonyState _state;
  final _buffer = StringBuffer();
  var _toolCallName = '';

  // Guard buffer for handling tags split across chunks.
  var _pending = '';

  @override
  Iterable<ModelOutput> add(StreamChunk chunk) sync* {
    // _pending must be a String (not StringBuffer) since we use substring.
    _pending = '$_pending${chunk.text}';

    // Process pending text, scanning for tags.
    while (_pending.isNotEmpty) {
      final scan = _scanForTag(_pending);

      if (scan == null) {
        // No complete tag found. Keep a guard buffer for partial tags.
        final flushed = _flushWithGuard(_pending);
        if (flushed.isNotEmpty) {
          switch (_state) {
            case _HarmonyState.inAnalysis:
              yield ModelReasoningDelta(flushed);
            case _HarmonyState.inFinal:
              yield ModelTextDelta(flushed);
            case _HarmonyState.inToolCallBody:
              _buffer.write(flushed);
            case _HarmonyState.awaitingDirective:
            case _HarmonyState.readingChannel:
            case _HarmonyState.inToolCallRouting:
              // Accumulate directive/channel/routing text.
              _buffer.write(flushed);
          }
          _pending = _guardRemainder(_pending);
        }
        break;
      }

      // Emit text before the tag.
      final before = _pending.substring(0, scan.index);
      if (before.isNotEmpty) {
        switch (_state) {
          case _HarmonyState.inAnalysis:
            yield ModelReasoningDelta(before);
          case _HarmonyState.inFinal:
            yield ModelTextDelta(before);
          case _HarmonyState.inToolCallBody:
            _buffer.write(before);
          case _HarmonyState.awaitingDirective:
          case _HarmonyState.readingChannel:
          case _HarmonyState.inToolCallRouting:
            _buffer.write(before);
        }
      }

      // Advance past the tag.
      _pending = _pending.substring(scan.index + scan.tag.length);

      // Handle the tag based on current state.
      switch (scan.tagType) {
        case _HarmonyTag.channel:
          if (_state == _HarmonyState.inToolCallRouting) {
            // Buffer contains the function name (text after
            // "to=functions.").
            _toolCallName = _buffer.toString().trim();
            _buffer.clear();
          } else {
            _buffer.clear();
          }
          _state = _HarmonyState.readingChannel;

        case _HarmonyTag.message:
          // Transition from readingChannel to content state.
          final channelInfo = _buffer.toString().trim();
          _buffer.clear();

          if (_toolCallName.isNotEmpty &&
              channelInfo.startsWith('commentary')) {
            _state = _HarmonyState.inToolCallBody;
          } else if (_extractToolName(channelInfo) case final name?) {
            // Correct Harmony spec: tool name embedded in channel text.
            _toolCallName = name;
            _state = _HarmonyState.inToolCallBody;
          } else if (channelInfo == 'analysis') {
            _state = _HarmonyState.inAnalysis;
          } else if (channelInfo == 'final') {
            _state = _HarmonyState.inFinal;
          } else if (channelInfo.startsWith('commentary')) {
            // Tool result or other commentary — skip content.
            _state = _HarmonyState.inFinal;
          } else {
            // Unknown channel — treat as final.
            _state = _HarmonyState.inFinal;
          }

        case _HarmonyTag.end:
          _state = _HarmonyState.awaitingDirective;
          _buffer.clear();
          _toolCallName = '';

        case _HarmonyTag.call:
          if (_state == _HarmonyState.inToolCallBody) {
            final argsStr = _buffer.toString().trim();
            _buffer.clear();
            yield _toolCallFrom(argsStr);
          }
          _state = _HarmonyState.awaitingDirective;
          _toolCallName = '';

        case _HarmonyTag.start:
          // New message boundary. Reset state.
          _state = _HarmonyState.awaitingDirective;
          _buffer.clear();

        case _HarmonyTag.toFunctions:
          if (_state == _HarmonyState.readingChannel) {
            // Correct Harmony spec: routing is inside channel text.
            // Keep the pseudo-tag in the buffer for _extractToolName.
            _buffer.write('to=functions.');
          } else {
            // Legacy format: to=functions. before <|channel|>.
            _state = _HarmonyState.inToolCallRouting;
            _buffer.clear();
          }

        case _HarmonyTag.constrain:
          // Constraint directive (e.g., json). Keep accumulating in the
          // current state — this is handled as part of channel info.
          break;
      }
    }

    // Emit token count after text classification.
    if (chunk.tokenCountDelta > 0) {
      yield ModelTokensGenerated(chunk.tokenCountDelta);
    }
  }

  @override
  Iterable<ModelOutput> finish() sync* {
    // Flush remaining pending text.
    if (_pending.isNotEmpty) {
      switch (_state) {
        case _HarmonyState.inAnalysis:
          yield ModelReasoningDelta(_pending);
        case _HarmonyState.inFinal:
          yield ModelTextDelta(_pending);
        case _HarmonyState.inToolCallBody:
          _buffer.write(_pending);
        case _HarmonyState.awaitingDirective:
        case _HarmonyState.readingChannel:
        case _HarmonyState.inToolCallRouting:
          _buffer.write(_pending);
      }
      _pending = '';
    }

    // Handle stream end with buffered tool call.
    if (_state == _HarmonyState.inToolCallBody && _buffer.isNotEmpty) {
      yield _toolCallFrom(_buffer.toString().trim());
    }

    yield const ModelStepFinished(ModelStopReason.stop);
  }

  /// Builds the routed tool call from its argument body, or reports the
  /// attempt as [ModelToolCallUnparsed] when the body isn't valid JSON.
  ModelOutput _toolCallFrom(String argsStr) {
    try {
      final decoded = jsonDecode(argsStr);
      final args = decoded is Map<String, Object?>
          ? decoded
          : <String, Object?>{};
      return ModelToolCallOutput(
        ToolCallDefault(
          id: 'harmony_${_nextToolCallId()}',
          name: _toolCallName,
          arguments: args,
        ),
      );
    } on FormatException {
      return ModelToolCallUnparsed(rawText: argsStr, name: _toolCallName);
    }
  }
}

// ── Tag scanning ─────────────────────────────────────────

enum _HarmonyState {
  awaitingDirective,
  readingChannel,
  inAnalysis,
  inFinal,
  inToolCallRouting,
  inToolCallBody,
}

enum _HarmonyTag { channel, message, end, call, start, toFunctions, constrain }

final class _TagScanResult {
  const _TagScanResult({
    required this.index,
    required this.tag,
    required this.tagType,
  });

  final int index;
  final String tag;
  final _HarmonyTag tagType;
}

/// Every tag the parser recognises, including the `to=functions.` routing
/// directive, which is scanned like a tag.
const _tagPatterns = <String, _HarmonyTag>{
  '<|channel|>': _HarmonyTag.channel,
  '<|message|>': _HarmonyTag.message,
  '<|end|>': _HarmonyTag.end,
  '<|call|>': _HarmonyTag.call,
  '<|start|>': _HarmonyTag.start,
  '<|constrain|>': _HarmonyTag.constrain,
  'to=functions.': _HarmonyTag.toFunctions,
};

/// Maximum tag length for guard buffer calculation.
const _maxTagLength = 14; // '<|constrain|>' is the longest at 13 chars + 1

_TagScanResult? _scanForTag(String text) {
  _TagScanResult? earliest;

  for (final MapEntry(key: tag, value: tagType) in _tagPatterns.entries) {
    final index = text.indexOf(tag);
    if (index == -1) continue;
    if (earliest == null || index < earliest.index) {
      earliest = _TagScanResult(index: index, tag: tag, tagType: tagType);
    }
  }

  return earliest;
}

/// Extracts a tool name from channel text like
/// `commentary to=functions.get_weather json`.
String? _extractToolName(String channelInfo) {
  if (!channelInfo.contains('to=functions.')) return null;
  final match = RegExp(r'to=functions\.(\S+)').firstMatch(channelInfo);
  return match?.group(1);
}

/// Flushes text up to the guard boundary (keeps last _maxTagLength - 1
/// characters to handle tags split across chunks).
String _flushWithGuard(String text) {
  const guard = _maxTagLength - 1;
  if (text.length <= guard) return '';
  return text.substring(0, text.length - guard);
}

/// Returns the guard remainder (last _maxTagLength - 1 characters).
String _guardRemainder(String text) {
  const guard = _maxTagLength - 1;
  if (text.length <= guard) return text;
  return text.substring(text.length - guard);
}
