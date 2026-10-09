import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

/// Feeds each chunk to the tokenizer and collects all tokens, then flushes.
List<StreamToken> feedAll(StreamTokenizer tokenizer, List<String> chunks) {
  final tokens = <StreamToken>[];
  for (final chunk in chunks) {
    tokens.addAll(tokenizer.feed(chunk));
  }
  tokens.addAll(tokenizer.flush());
  return tokens;
}

void main() {
  group('StreamTokenizer', () {
    late StreamTokenizer tokenizer;

    setUp(() {
      tokenizer = StreamTokenizer();
    });

    test('emits text tokens for plain text', () {
      final tokens = feedAll(tokenizer, ['Hello world']);

      expect(tokens, hasLength(1));
      expect(tokens[0].type, StreamTokenType.text);
      expect(tokens[0].text, 'Hello world');
    });

    test('emits think start/end tokens', () {
      final tokens = feedAll(tokenizer, ['<think>reasoning</think>']);

      expect(tokens, hasLength(3));
      expect(tokens[0].type, StreamTokenType.thinkStart);
      expect(tokens[1].type, StreamTokenType.text);
      expect(tokens[1].text, 'reasoning');
      expect(tokens[2].type, StreamTokenType.thinkEnd);
    });

    test('emits tool start/end tokens', () {
      final tokens = feedAll(
        tokenizer,
        ['<tool_call>{"name":"test"}</tool_call>'],
      );

      expect(tokens, hasLength(3));
      expect(tokens[0].type, StreamTokenType.toolStart);
      expect(tokens[1].type, StreamTokenType.text);
      expect(tokens[1].text, '{"name":"test"}');
      expect(tokens[2].type, StreamTokenType.toolEnd);
    });

    test('handles tags split across chunks', () {
      final tokens = feedAll(tokenizer, [
        '<thi',
        'nk>inner</thi',
        'nk>after',
      ]);

      expect(tokens, hasLength(4));
      expect(tokens[0].type, StreamTokenType.thinkStart);
      expect(tokens[1].type, StreamTokenType.text);
      expect(tokens[1].text, 'inner');
      expect(tokens[2].type, StreamTokenType.thinkEnd);
      expect(tokens[3].type, StreamTokenType.text);
      expect(tokens[3].text, 'after');
    });

    test('handles text before and after tags', () {
      final tokens = feedAll(
        tokenizer,
        ['before<think>inner</think>after'],
      );

      expect(tokens, hasLength(5));
      expect(tokens[0].type, StreamTokenType.text);
      expect(tokens[0].text, 'before');
      expect(tokens[1].type, StreamTokenType.thinkStart);
      expect(tokens[2].type, StreamTokenType.text);
      expect(tokens[2].text, 'inner');
      expect(tokens[3].type, StreamTokenType.thinkEnd);
      expect(tokens[4].type, StreamTokenType.text);
      expect(tokens[4].text, 'after');
    });

    test('handles multiple sequential tags', () {
      final tokens = feedAll(
        tokenizer,
        ['<think>a</think><tool_call>b</tool_call>'],
      );

      expect(tokens, hasLength(6));
      expect(tokens[0].type, StreamTokenType.thinkStart);
      expect(tokens[1].type, StreamTokenType.text);
      expect(tokens[1].text, 'a');
      expect(tokens[2].type, StreamTokenType.thinkEnd);
      expect(tokens[3].type, StreamTokenType.toolStart);
      expect(tokens[4].type, StreamTokenType.text);
      expect(tokens[4].text, 'b');
      expect(tokens[5].type, StreamTokenType.toolEnd);
    });

    test('handles empty input', () {
      final tokens = tokenizer.flush();
      expect(tokens, isEmpty);
    });

    test('handles single character chunks', () {
      const text = '<think>hi</think>';
      final tokens = feedAll(tokenizer, text.split(''));

      final types = tokens.map((t) => t.type).toList();
      expect(types, contains(StreamTokenType.thinkStart));
      expect(types, contains(StreamTokenType.thinkEnd));

      final textContent = tokens
          .where((t) => t.type == StreamTokenType.text)
          .map((t) => t.text)
          .join();
      expect(textContent, 'hi');
    });
  });

  group('StreamTokenizer with custom tags', () {
    test('recognizes custom tags instead of defaults', () {
      final tokenizer = StreamTokenizer(
        tags: const [
          TagDefinition(
            tag: '[TOOL_CALLS]',
            type: StreamTokenType.toolStart,
          ),
          TagDefinition(
            tag: '[/TOOL_CALLS]',
            type: StreamTokenType.toolEnd,
          ),
        ],
      );

      final tokens = feedAll(
        tokenizer,
        ['Before[TOOL_CALLS]tool content[/TOOL_CALLS]After'],
      );

      expect(tokens, hasLength(5));
      expect(tokens[0].type, StreamTokenType.text);
      expect(tokens[0].text, 'Before');
      expect(tokens[1].type, StreamTokenType.toolStart);
      expect(tokens[2].type, StreamTokenType.text);
      expect(tokens[2].text, 'tool content');
      expect(tokens[3].type, StreamTokenType.toolEnd);
      expect(tokens[4].type, StreamTokenType.text);
      expect(tokens[4].text, 'After');
    });

    test('does not recognize default tags when custom tags are set', () {
      final tokenizer = StreamTokenizer(
        tags: const [
          TagDefinition(
            tag: '[START]',
            type: StreamTokenType.toolStart,
          ),
        ],
      );

      final tokens = feedAll(tokenizer, ['<think>not a tag</think>']);

      // The default <think> tags should be treated as plain text.
      // May be split into multiple text tokens due to guard buffering.
      expect(tokens.every((t) => t.type == StreamTokenType.text), isTrue);
      final combined = tokens.map((t) => t.text).join();
      expect(combined, '<think>not a tag</think>');
    });

    test('handles custom tags split across chunks', () {
      final tokenizer = StreamTokenizer(
        tags: const [
          TagDefinition(
            tag: '<<BEGIN>>',
            type: StreamTokenType.thinkStart,
          ),
          TagDefinition(
            tag: '<<END>>',
            type: StreamTokenType.thinkEnd,
          ),
        ],
      );

      final tokens = feedAll(tokenizer, [
        '<<BEG',
        'IN>>content<<EN',
        'D>>',
      ]);

      final types = tokens.map((t) => t.type).toList();
      expect(types, contains(StreamTokenType.thinkStart));
      expect(types, contains(StreamTokenType.thinkEnd));

      // Text between tags may be split due to guard buffering.
      final textContent = tokens
          .where((t) => t.type == StreamTokenType.text)
          .map((t) => t.text)
          .join();
      expect(textContent, 'content');
    });
  });

  group('StreamTokenizer keepInBuffer', () {
    test('emits tagText for tags marked keepInBuffer', () {
      final tokenizer = StreamTokenizer(
        tags: const [
          TagDefinition(
            tag: '<function=',
            type: StreamTokenType.toolStart,
            keepInBuffer: true,
          ),
          TagDefinition(
            tag: '</function>',
            type: StreamTokenType.toolEnd,
            keepInBuffer: true,
          ),
        ],
      );

      final tokens = feedAll(tokenizer, ['<function=foo>body</function>']);

      final start = tokens.firstWhere(
        (t) => t.type == StreamTokenType.toolStart,
      );
      expect(start.tagText, '<function=');
      expect(start.text, isNull);

      final end = tokens.firstWhere(
        (t) => t.type == StreamTokenType.toolEnd,
      );
      expect(end.tagText, '</function>');
      expect(end.text, isNull);
    });

    test('omits tagText for tags not marked keepInBuffer', () {
      final tokenizer = StreamTokenizer();

      final tokens = feedAll(
        tokenizer,
        ['<think>reasoning</think>'],
      );

      final start = tokens.firstWhere(
        (t) => t.type == StreamTokenType.thinkStart,
      );
      expect(start.tagText, isNull);
    });
  });
}
