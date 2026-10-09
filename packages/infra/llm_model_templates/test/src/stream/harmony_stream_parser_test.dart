import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

import '../../helpers/parse_all.dart';

void main() {
  group('HarmonyStreamParser', () {
    late HarmonyStreamParser parser;

    setUp(() {
      parser = HarmonyStreamParser();
    });

    List<StreamChunk> chunksFromString(String text, {int chunkSize = 100}) {
      final chunks = <StreamChunk>[];
      for (var i = 0; i < text.length; i += chunkSize) {
        final end = i + chunkSize;
        chunks.add(
          StreamChunk(
            text: text.substring(i, end > text.length ? text.length : end),
            tokenCountDelta: 1,
          ),
        );
      }
      return chunks;
    }

    test('parses analysis channel as reasoning output', () async {
      final stream = chunksFromString(
        '<|channel|>analysis<|message|>Let me think...<|end|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final reasoning = outputs.whereType<ModelReasoningDelta>().toList();
      expect(reasoning, isNotEmpty);
      expect(reasoning.map((r) => r.text).join(), 'Let me think...');
    });

    test('parses final channel as text output', () async {
      final stream = chunksFromString(
        '<|channel|>final<|message|>Hello world!<|end|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final text = outputs.whereType<ModelTextDelta>().toList();
      expect(text, isNotEmpty);
      expect(text.map((t) => t.text).join(), 'Hello world!');
    });

    test('prefilled session routes leading bare text as final output', () {
      final session = parser.start(answerPrefilled: true);
      final outputs = <ModelOutput>[
        ...session.add(
          const StreamChunk(text: 'summary body', tokenCountDelta: 1),
        ),
        ...session.finish(),
      ];

      final text = outputs
          .whereType<ModelTextDelta>()
          .map((t) => t.text)
          .join();
      expect(text, 'summary body');
    });

    test('prefilled session still routes an explicit analysis channel', () {
      final session = parser.start(answerPrefilled: true);
      final outputs = <ModelOutput>[
        ...session.add(
          const StreamChunk(
            text: '<|channel|>analysis<|message|>hmm<|end|>',
            tokenCountDelta: 1,
          ),
        ),
        ...session.finish(),
      ];

      final reasoning = outputs
          .whereType<ModelReasoningDelta>()
          .map((r) => r.text)
          .join();
      expect(reasoning, 'hmm');
    });

    test('parses tool call with routing and JSON body', () async {
      final stream = chunksFromString(
        'to=functions.get_weather<|channel|>commentary'
        ' json<|message|>{"location":"Paris"}<|call|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final toolCalls = outputs.whereType<ModelToolCallOutput>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.call.name, 'get_weather');
      expect(
        toolCalls.first.call.arguments,
        {'location': 'Paris'},
      );
    });

    test('parses tool call with spec-correct channel routing', () async {
      // Correct Harmony spec: to=functions.NAME inside channel text.
      final stream = chunksFromString(
        '<|channel|>commentary to=functions.get_weather'
        ' <|constrain|>json<|message|>{"location":"Paris"}<|call|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final toolCalls = outputs.whereType<ModelToolCallOutput>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.call.name, 'get_weather');
      expect(
        toolCalls.first.call.arguments,
        {'location': 'Paris'},
      );
    });

    test('parses tool call at stream end with spec-correct format', () async {
      final stream = chunksFromString(
        '<|channel|>commentary to=functions.search'
        ' <|constrain|>json<|message|>{"query":"dart"}',
      );
      final outputs = parser.parseAll(stream).toList();

      final toolCalls = outputs.whereType<ModelToolCallOutput>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.call.name, 'search');
      expect(toolCalls.first.call.arguments, {'query': 'dart'});
    });

    test('handles analysis followed by final channel', () async {
      final stream = chunksFromString(
        '<|channel|>analysis<|message|>Thinking...<|end|>'
        '<|start|>assistant<|channel|>final<|message|>Done!<|end|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final reasoning = outputs.whereType<ModelReasoningDelta>().toList();
      final text = outputs.whereType<ModelTextDelta>().toList();
      expect(reasoning.map((r) => r.text).join(), 'Thinking...');
      expect(text.map((t) => t.text).join(), 'Done!');
    });

    test('handles cross-chunk tag splitting', () async {
      // Split '<|channel|>' across two chunks.
      final chunks = [
        const StreamChunk(text: 'Hello<|chan', tokenCountDelta: 1),
        const StreamChunk(
          text: 'nel|>final<|message|>World',
          tokenCountDelta: 1,
        ),
        const StreamChunk(text: '<|end|>', tokenCountDelta: 1),
      ];
      final outputs = parser.parseAll(chunks).toList();

      final text = outputs.whereType<ModelTextDelta>().toList();
      // 'Hello' goes to awaitingDirective buffer, then final channel text.
      expect(text.map((t) => t.text).join(), 'World');
    });

    test('emits ModelStepFinished at end', () async {
      final stream = chunksFromString(
        '<|channel|>final<|message|>Hi<|end|>',
      );
      final outputs = parser.parseAll(stream).toList();

      expect(outputs.last, isA<ModelStepFinished>());
      expect(
        (outputs.last as ModelStepFinished).reason,
        ModelStopReason.stop,
      );
    });

    test('empty stream yields only step finished', () async {
      final outputs = parser.parseAll(const <StreamChunk>[]).toList();

      expect(outputs, hasLength(1));
      expect(outputs.first, isA<ModelStepFinished>());
    });

    test('emits token counts', () async {
      final chunks = [
        const StreamChunk(
          text: '<|channel|>final<|message|>Hi<|end|>',
          tokenCountDelta: 5,
        ),
      ];
      final outputs = parser.parseAll(chunks).toList();

      final tokenCounts = outputs.whereType<ModelTokensGenerated>().toList();
      expect(tokenCounts, isNotEmpty);
    });

    test('handles tool call at stream end without call tag', () async {
      // Model ends mid-tool-call (no <|call|> tag).
      final stream = chunksFromString(
        'to=functions.search<|channel|>commentary'
        ' json<|message|>{"query":"dart"}',
      );
      final outputs = parser.parseAll(stream).toList();

      final toolCalls = outputs.whereType<ModelToolCallOutput>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.call.name, 'search');
      expect(toolCalls.first.call.arguments, {'query': 'dart'});
    });

    test('malformed JSON in tool call surfaces the attempt', () async {
      final stream = chunksFromString(
        'to=functions.search<|channel|>commentary'
        ' json<|message|>{not valid json}<|call|>',
      );
      final outputs = parser.parseAll(stream).toList();

      expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
      final unparsed = outputs.whereType<ModelToolCallUnparsed>().single;
      expect(unparsed.rawText, '{not valid json}');
      expect(unparsed.name, 'search');
    });

    test('flushes analysis text via guard buffer with tiny chunks', () async {
      // Feed analysis content one character at a time so the guard buffer
      // path is exercised (covers line 49).
      final chunks = <StreamChunk>[];
      const text =
          '<|channel|>analysis<|message|>This is a long reasoning passage'
          ' that must flush via guard.<|end|>';
      for (var i = 0; i < text.length; i++) {
        chunks.add(StreamChunk(text: text[i], tokenCountDelta: 1));
      }
      final outputs = parser.parseAll(chunks).toList();

      final reasoning = outputs.whereType<ModelReasoningDelta>().toList();
      expect(
        reasoning.map((r) => r.text).join(),
        'This is a long reasoning passage that must flush via guard.',
      );
    });

    test('flushes final text via guard buffer with tiny chunks', () async {
      // Feed final content one character at a time (covers line 51).
      final chunks = <StreamChunk>[];
      const text =
          '<|channel|>final<|message|>This is a long final passage'
          ' that must flush via guard.<|end|>';
      for (var i = 0; i < text.length; i++) {
        chunks.add(StreamChunk(text: text[i], tokenCountDelta: 1));
      }
      final outputs = parser.parseAll(chunks).toList();

      final textDeltas = outputs.whereType<ModelTextDelta>().toList();
      expect(
        textDeltas.map((t) => t.text).join(),
        'This is a long final passage that must flush via guard.',
      );
    });

    test('buffers tool call body via guard with tiny chunks', () async {
      // Tiny-chunk a tool call body so the guard flush hits
      // _HarmonyState.inToolCallBody (covers line 56).
      final chunks = <StreamChunk>[];
      const text =
          'to=functions.search<|channel|>commentary'
          ' json<|message|>{"query":"something long enough"}<|call|>';
      for (var i = 0; i < text.length; i++) {
        chunks.add(StreamChunk(text: text[i], tokenCountDelta: 1));
      }
      final outputs = parser.parseAll(chunks).toList();

      final toolCalls = outputs.whereType<ModelToolCallOutput>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.call.name, 'search');
    });

    test('commentary channel without tool name treated as final', () async {
      // A commentary message without routing — should hit the
      // channelInfo.startsWith('commentary') branch (line 114).
      final stream = chunksFromString(
        '<|channel|>commentary<|message|>Some note<|end|>',
      );
      final outputs = parser.parseAll(stream).toList();

      // Content treated as final text.
      final text = outputs.whereType<ModelTextDelta>().toList();
      expect(text.map((t) => t.text).join(), 'Some note');
    });

    test('tool call with non-map JSON decoded as empty args', () async {
      // JSON decodes to a non-map value → args = {} (covers line 137).
      final stream = chunksFromString(
        'to=functions.noop<|channel|>commentary'
        ' json<|message|>"just a string"<|call|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final toolCalls = outputs.whereType<ModelToolCallOutput>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.call.arguments, isEmpty);
    });

    test('flushes remaining analysis text at stream end', () async {
      // Stream ends mid-analysis with no closing tag (covers line 186).
      final stream = chunksFromString(
        '<|channel|>analysis<|message|>Partial reasoning',
      );
      final outputs = parser.parseAll(stream).toList();

      final reasoning = outputs.whereType<ModelReasoningDelta>().toList();
      expect(reasoning.map((r) => r.text).join(), 'Partial reasoning');
    });

    test('flushes remaining final text at stream end', () async {
      // Stream ends mid-final with no closing tag (covers line 188).
      final stream = chunksFromString(
        '<|channel|>final<|message|>Partial response',
      );
      final outputs = parser.parseAll(stream).toList();

      final text = outputs.whereType<ModelTextDelta>().toList();
      expect(text.map((t) => t.text).join(), 'Partial response');
    });

    test('flushes remaining text in other states at stream end', () async {
      // Stream ends in readingChannel state (covers lines 191-194).
      final stream = chunksFromString('<|channel|>partial');
      final outputs = parser.parseAll(stream).toList();

      // No text or reasoning emitted — just step finished.
      expect(outputs.last, isA<ModelStepFinished>());
    });

    test('tool call body at stream end with non-map JSON', () async {
      // Stream ends with tool call body containing non-map JSON
      // (covers line 205 — buffer.write(pending) for toolCallBody).
      final stream = chunksFromString(
        'to=functions.check<|channel|>commentary'
        ' json<|message|>42',
      );
      final outputs = parser.parseAll(stream).toList();

      final toolCalls = outputs.whereType<ModelToolCallOutput>().toList();
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.call.arguments, isEmpty);
    });

    test('increments tool call ids across parse calls', () async {
      List<ModelToolCallOutput> parseToolCall() {
        final stream = chunksFromString(
          '<|channel|>commentary to=functions.check'
          ' <|constrain|>json<|message|>{}<|call|>',
        );
        return parser
            .parseAll(stream)
            .whereType<ModelToolCallOutput>()
            .toList();
      }

      final first = parseToolCall();
      final second = parseToolCall();

      expect(first.single.call.id, 'harmony_0');
      expect(second.single.call.id, 'harmony_1');
    });

    test('malformed JSON at stream end surfaces the attempt', () async {
      final stream = chunksFromString(
        'to=functions.bad<|channel|>commentary'
        ' json<|message|>{not valid',
      );
      final outputs = parser.parseAll(stream).toList();

      expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
      final unparsed = outputs.whereType<ModelToolCallUnparsed>().single;
      expect(unparsed.rawText, '{not valid');
      expect(unparsed.name, 'bad');
    });

    test('flushes remaining text in tool call routing state', () async {
      // Stream ends in inToolCallRouting state (covers line 193).
      // "to=functions." triggers the routing state, then stream ends
      // before a <|channel|> tag.
      final stream = chunksFromString('to=functions.partial_name');
      final outputs = parser.parseAll(stream).toList();

      // No tool calls or text emitted — just step finished.
      expect(outputs.last, isA<ModelStepFinished>());
    });

    test('start tag resets state', () async {
      final stream = chunksFromString(
        '<|start|>assistant<|channel|>final<|message|>First<|end|>'
        '<|start|>assistant<|channel|>final<|message|>Second<|end|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final text = outputs.whereType<ModelTextDelta>().toList();
      final combined = text.map((t) => t.text).join();
      expect(combined, contains('First'));
      expect(combined, contains('Second'));
    });

    test('unknown channels are treated as final text', () async {
      final stream = chunksFromString(
        '<|channel|>mystery<|message|>Visible text<|end|>',
      );
      final outputs = parser.parseAll(stream).toList();

      final text = outputs.whereType<ModelTextDelta>().toList();
      expect(text.map((t) => t.text).join(), 'Visible text');
    });
  });
}
