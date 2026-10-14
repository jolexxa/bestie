import 'dart:math' as math;

/// Token types emitted by the stream tokenizer.
enum StreamTokenType {
  /// Normal text content.
  text,

  /// Opening `<think>` tag.
  thinkStart,

  /// Closing `</think>` tag.
  thinkEnd,

  /// Opening `<tool_call>` tag.
  toolStart,

  /// Closing `</tool_call>` tag.
  toolEnd,
}

/// A token emitted by the stream tokenizer.
final class StreamToken {
  /// A run of plain text.
  const StreamToken.text(String this.text)
    : type = StreamTokenType.text,
      tagText = null;

  /// A matched tag, carrying its literal [tagText] when the definition keeps
  /// it in the buffer.
  const StreamToken.tag(this.type, {this.tagText}) : text = null;

  /// The kind of token.
  final StreamTokenType type;

  /// The text of a [StreamTokenType.text] token.
  final String? text;

  /// The literal matched tag, for tags whose definition sets
  /// [TagDefinition.keepInBuffer], so the parser can preserve it in a
  /// buffered tool-call span.
  final String? tagText;
}

/// Defines a mapping from a tag string to a [StreamTokenType].
final class TagDefinition {
  /// Creates a tag definition.
  const TagDefinition({
    required this.tag,
    required this.type,
    this.keepInBuffer = false,
  });

  /// The literal tag text to match.
  final String tag;

  /// The token type a match emits.
  final StreamTokenType type;

  /// Whether a match carries the tag string as [StreamToken.tagText] — used
  /// for tags like `<function=` that double as literal content inside a
  /// buffered tool-call body.
  final bool keepInBuffer;
}

/// Tokenizes string chunks into typed tokens with synchronous feed/flush.
///
/// Handles tag boundaries across chunk boundaries by buffering and using
/// a guard length to avoid flushing partial tags.
final class StreamTokenizer {
  /// Creates a tokenizer with optional custom [tags].
  ///
  /// When [tags] is null, the default ChatML/Qwen tags are used.
  StreamTokenizer({List<TagDefinition>? tags})
    : _tags = tags ?? defaultTags,
      _maxTagLength = _computeMaxTagLength(tags ?? defaultTags);

  final List<TagDefinition> _tags;
  final int _maxTagLength;
  final _buffer = StringBuffer();

  /// Default ChatML/Qwen tags: `<think>`, `</think>`, `<tool_call>`,
  /// `</tool_call>`.
  static const defaultTags = <TagDefinition>[
    TagDefinition(tag: '<think>', type: StreamTokenType.thinkStart),
    TagDefinition(tag: '</think>', type: StreamTokenType.thinkEnd),
    TagDefinition(tag: '<tool_call>', type: StreamTokenType.toolStart),
    TagDefinition(tag: '</tool_call>', type: StreamTokenType.toolEnd),
  ];

  static int _computeMaxTagLength(List<TagDefinition> tags) {
    var max = 0;
    for (final definition in tags) {
      if (definition.tag.length > max) max = definition.tag.length;
    }
    return max;
  }

  /// Feeds a chunk of text and returns any tokens that can be resolved.
  ///
  /// Keeps a guard buffer to handle tags split across chunk boundaries.
  List<StreamToken> feed(String chunk) {
    _buffer.write(chunk);
    return _processBuffer(isFinal: false);
  }

  /// Flushes the remaining buffer as text. Call after the last chunk.
  List<StreamToken> flush() => _processBuffer(isFinal: true);

  List<StreamToken> _processBuffer({required bool isFinal}) {
    final tokens = <StreamToken>[];

    while (_buffer.isNotEmpty) {
      final bufferStr = _buffer.toString();
      final match = _findEarliestTag(bufferStr);

      if (match == null) {
        if (isFinal) {
          tokens.add(StreamToken.text(bufferStr));
          _buffer.clear();
        } else {
          final flushLength = _flushableLength(bufferStr, _maxTagLength);
          if (flushLength > 0) {
            tokens.add(StreamToken.text(bufferStr.substring(0, flushLength)));
          }
          _buffer
            ..clear()
            ..write(bufferStr.substring(flushLength));
        }
        break;
      }

      // Emit text before tag.
      if (match.index > 0) {
        tokens.add(StreamToken.text(bufferStr.substring(0, match.index)));
      }

      // Emit tag token. Preserve the matched tag string when the
      // definition opted in via keepInBuffer.
      final definition = match.definition;
      tokens.add(
        StreamToken.tag(
          definition.type,
          tagText: definition.keepInBuffer ? definition.tag : null,
        ),
      );
      _buffer
        ..clear()
        ..write(bufferStr.substring(match.index + definition.tag.length));
    }

    return tokens;
  }

  _TagMatch? _findEarliestTag(String buffer) {
    _TagMatch? earliest;

    for (final definition in _tags) {
      final index = buffer.indexOf(definition.tag);
      if (index == -1) continue;
      if (earliest == null || index < earliest.index) {
        earliest = _TagMatch(index: index, definition: definition);
      }
    }

    return earliest;
  }

  /// How much of [buffer] can be emitted while holding back enough characters
  /// to complete a tag split across chunks.
  static int _flushableLength(String buffer, int guardLength) {
    if (guardLength <= 0) return buffer.length;
    return math.max(0, buffer.length - (guardLength - 1));
  }
}

final class _TagMatch {
  const _TagMatch({required this.index, required this.definition});

  final int index;
  final TagDefinition definition;
}
