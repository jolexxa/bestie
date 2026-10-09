import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

import '../../helpers/parse_all.dart';

void main() {
  group('UniversalStreamParser', () {
    group('tag-based mode (default config)', () {
      late UniversalStreamParser parser;

      setUp(() {
        parser = UniversalStreamParser(
          config: StreamParserConfig(
            toolCallExtractor: JsonToolCallExtractor(),
            tags: StreamTokenizer.defaultTags,
            supportsReasoning: true,
          ),
        );
      });

      test('parses reasoning, text, tool calls, and finish', () async {
        const toolJson = '{"id":"1","name":"search","arguments":{"query":"q"}}';
        const chunks = [
          StreamChunk(
            text: '<think>Quiet plan.</think>',
            tokenCountDelta: 0,
          ),
          StreamChunk(
            text: 'Working...<tool_call>$toolJson</tool_call>',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        expect(outputs, hasLength(4));
        expect(outputs[0], isA<ModelReasoningDelta>());
        expect((outputs[0] as ModelReasoningDelta).text, 'Quiet plan.');
        expect(outputs[1], isA<ModelTextDelta>());
        expect((outputs[1] as ModelTextDelta).text, contains('Working...'));
        expect(outputs[2], isA<ModelToolCallOutput>());
        expect((outputs[2] as ModelToolCallOutput).call.name, 'search');
        expect(outputs[3], isA<ModelStepFinished>());
      });

      test('starts mid-reasoning when reasoning was prefilled', () {
        const toolJson = '{"id":"1","name":"search","arguments":{"query":"q"}}';
        final session = parser.start(reasoningPrefilled: true);

        final outputs = [
          ...session.add(
            const StreamChunk(text: 'Quiet plan.</think>', tokenCountDelta: 0),
          ),
          ...session.add(
            const StreamChunk(
              text: 'Working...<tool_call>$toolJson</tool_call>',
              tokenCountDelta: 0,
            ),
          ),
          ...session.finish(),
        ];

        expect(outputs[0], isA<ModelReasoningDelta>());
        expect((outputs[0] as ModelReasoningDelta).text, 'Quiet plan.');
        expect(outputs[1], isA<ModelTextDelta>());
        expect((outputs[1] as ModelTextDelta).text, contains('Working...'));
        expect(outputs[2], isA<ModelToolCallOutput>());
        expect((outputs[2] as ModelToolCallOutput).call.name, 'search');
      });

      test('prefilled reasoning start emits no leading text deltas', () {
        final session = parser.start(reasoningPrefilled: true);

        final outputs = [
          ...session.add(
            const StreamChunk(
              text: 'Only thoughts, no close',
              tokenCountDelta: 0,
            ),
          ),
          ...session.finish(),
        ];

        expect(outputs.whereType<ModelTextDelta>(), isEmpty);
        expect(
          outputs.whereType<ModelReasoningDelta>().map((d) => d.text).join(),
          'Only thoughts, no close',
        );
      });

      test('ignores reasoningPrefilled when reasoning is unsupported', () {
        final plainParser = UniversalStreamParser(
          config: StreamParserConfig(
            toolCallExtractor: JsonToolCallExtractor(),
            tags: StreamTokenizer.defaultTags,
            supportsReasoning: false,
          ),
        );
        final session = plainParser.start(reasoningPrefilled: true);

        final outputs = [
          ...session.add(const StreamChunk(text: 'Hello', tokenCountDelta: 0)),
          ...session.finish(),
        ];

        expect(
          outputs.whereType<ModelTextDelta>().single.text,
          'Hello',
        );
      });

      test('handles tag boundaries across chunks', () async {
        const chunks = [
          StreamChunk(text: '<think>Plan', tokenCountDelta: 0),
          StreamChunk(text: '.</think>Hi ', tokenCountDelta: 0),
          StreamChunk(
            text:
                '<tool_call>{"name":"lookup","arguments":{"id":42}}</tool_call>',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        expect(outputs, hasLength(4));
        expect(outputs[0], isA<ModelReasoningDelta>());
        expect((outputs[0] as ModelReasoningDelta).text, 'Plan.');
        expect(outputs[1], isA<ModelTextDelta>());
        expect((outputs[1] as ModelTextDelta).text, 'Hi ');
        expect(outputs[2], isA<ModelToolCallOutput>());
        expect(outputs[3], isA<ModelStepFinished>());
      });

      test('handles plain text without special tags', () async {
        const chunks = [
          StreamChunk(text: 'Hello ', tokenCountDelta: 0),
          StreamChunk(text: 'world!', tokenCountDelta: 0),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final textOutputs = outputs.whereType<ModelTextDelta>().toList();
        final combinedText = textOutputs.map((output) => output.text).join();
        expect(combinedText, 'Hello world!');
        expect(outputs.last, isA<ModelStepFinished>());
      });

      test('handles multiple reasoning blocks', () async {
        const chunks = [
          StreamChunk(
            text:
                '<think>First thought.</think>Middle text<think>Second thought.</think>',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final reasoningOutputs = outputs
            .whereType<ModelReasoningDelta>()
            .toList();
        expect(reasoningOutputs, hasLength(2));
        expect(reasoningOutputs[0].text, 'First thought.');
        expect(reasoningOutputs[1].text, 'Second thought.');
      });

      test('continues processing after tool calls', () async {
        const chunks = [
          StreamChunk(
            text: '<tool_call>{"name":"a","arguments":{}}</tool_call>',
            tokenCountDelta: 0,
          ),
          StreamChunk(
            text: 'This text is emitted after the tool call',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final toolCallOutput = outputs.whereType<ModelToolCallOutput>().single;
        expect(toolCallOutput.call.name, 'a');

        final textAfterTool = outputs
            .whereType<ModelTextDelta>()
            .map((o) => o.text)
            .join();
        expect(textAfterTool, 'This text is emitted after the tool call');
      });

      test('handles empty stream', () async {
        const chunks = <StreamChunk>[];

        final outputs = parser.parseAll(chunks).toList();

        expect(outputs, hasLength(1));
        expect(outputs.single, isA<ModelStepFinished>());
      });

      test('emits token updates', () async {
        const chunks = [
          StreamChunk(text: 'Hello', tokenCountDelta: 3),
          StreamChunk(text: ' world', tokenCountDelta: 2),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final tokenUpdates = outputs.whereType<ModelTokensGenerated>().toList();
        expect(tokenUpdates, hasLength(2));
        expect(tokenUpdates.first.count, 3);
        expect(tokenUpdates.last.count, 2);
      });

      test('emits token count for chunk with empty text', () async {
        const chunks = [
          StreamChunk(text: '', tokenCountDelta: 5),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final tokenUpdates = outputs.whereType<ModelTokensGenerated>().toList();
        expect(tokenUpdates, hasLength(1));
        expect(tokenUpdates.single.count, 5);
      });

      test('wrapped call with unregistered name passes through', () async {
        const toolJson = '{"name":"made_up_tool","arguments":{"x":1}}';
        const chunks = [
          StreamChunk(
            text: '<tool_call>$toolJson</tool_call>',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser
            .parseAll(chunks, knownToolNames: {'search'})
            .toList();

        final call = outputs.whereType<ModelToolCallOutput>().single.call;
        expect(call.name, 'made_up_tool');
        expect(call.arguments, {'x': 1});
      });

      test('wrapped call with unparseable JSON surfaces the attempt', () async {
        const body = "{'name': 'search', 'arguments': {'query': 'cows'}}";
        const chunks = [
          StreamChunk(
            text: '<tool_call>$body</tool_call>',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser
            .parseAll(chunks, knownToolNames: {'search'})
            .toList();

        expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
        final unparsed = outputs.whereType<ModelToolCallUnparsed>().single;
        expect(unparsed.rawText, body);
        expect(unparsed.name, isNull);
      });

      test(
        'wrapped call with fumbled arguments string surfaces the attempt',
        () async {
          // The model supplied arguments we cannot read — executing with none
          // would act on the wrong intent, so the call must not extract.
          const body =
              '{"name": "search", "arguments": "{\'query\': \'cows\'}"}';
          const chunks = [
            StreamChunk(
              text: '<tool_call>$body</tool_call>',
              tokenCountDelta: 0,
            ),
          ];

          final outputs = parser
              .parseAll(chunks, knownToolNames: {'search'})
              .toList();

          expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
          final unparsed = outputs.whereType<ModelToolCallUnparsed>().single;
          expect(unparsed.rawText, body);
        },
      );

      test('brace-less wrapped body flushes as narration text', () async {
        const body = 'this is where the JSON goes';
        const chunks = [
          StreamChunk(
            text: '<tool_call>$body</tool_call>',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser
            .parseAll(chunks, knownToolNames: {'search'})
            .toList();

        expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
        expect(outputs.whereType<ModelToolCallUnparsed>(), isEmpty);
        final text = outputs
            .whereType<ModelTextDelta>()
            .map((o) => o.text)
            .join();
        expect(text, body);
      });

      test('whitespace-only wrapped body yields nothing', () async {
        const chunks = [
          StreamChunk(text: '<tool_call>  \n </tool_call>', tokenCountDelta: 0),
        ];

        final outputs = parser
            .parseAll(chunks, knownToolNames: {'search'})
            .toList();

        expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
        expect(outputs.whereType<ModelToolCallUnparsed>(), isEmpty);
        expect(outputs.whereType<ModelTextDelta>(), isEmpty);
      });

      test('stream ending mid-wrapper with unparseable JSON surfaces the '
          'attempt', () async {
        const body = '{"name": "search", "arguments": {"query": "co';
        final session = parser.start(knownToolNames: {'search'});

        final outputs = [
          ...session.add(
            const StreamChunk(text: '<tool_call>$body', tokenCountDelta: 0),
          ),
          ...session.finish(),
        ];

        expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
        final unparsed = outputs.whereType<ModelToolCallUnparsed>().single;
        expect(unparsed.rawText, body);
      });

      test('flushes reasoning text at stream end', () async {
        // Stream ends while still in reasoning state (no </think>).
        const chunks = [
          StreamChunk(text: '<think>partial reasoning', tokenCountDelta: 0),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final reasoning = outputs
            .whereType<ModelReasoningDelta>()
            .map((o) => o.text)
            .join();
        expect(reasoning, contains('partial reasoning'));
      });
    });

    group('tool call without end tag (stream end)', () {
      test('parses tool call when stream ends mid-tool-call', () async {
        final parser = UniversalStreamParser(
          config: StreamParserConfig(
            toolCallExtractor: JsonToolCallExtractor(),
            tags: [
              const TagDefinition(
                tag: '[TOOL_CALLS]',
                type: StreamTokenType.toolStart,
              ),
            ],
            supportsReasoning: false,
          ),
        );

        const chunks = [
          StreamChunk(
            text:
                '[TOOL_CALLS][{"name": "search", "arguments": {"q": "test"}}]',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        expect(outputs.whereType<ModelToolCallOutput>(), hasLength(1));
      });
    });

    group('mismatched/unexpected tags', () {
      test('ignores unexpected closing tags in normal mode', () async {
        final parser = UniversalStreamParser(
          config: StreamParserConfig(
            toolCallExtractor: JsonToolCallExtractor(),
            tags: StreamTokenizer.defaultTags,
            supportsReasoning: true,
          ),
        );

        const chunks = [
          StreamChunk(
            text: 'Hello</think>world</tool_call>!',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final textOutputs = outputs.whereType<ModelTextDelta>().toList();
        final allText = textOutputs.map((output) => output.text).join();
        expect(allText, 'Helloworld!');
        expect(outputs.last, isA<ModelStepFinished>());
      });

      test('ignores unexpected tags inside reasoning mode', () async {
        final parser = UniversalStreamParser(
          config: StreamParserConfig(
            toolCallExtractor: JsonToolCallExtractor(),
            tags: StreamTokenizer.defaultTags,
            supportsReasoning: true,
          ),
        );

        // Nested think start + tool tags inside reasoning should be ignored.
        const chunks = [
          StreamChunk(
            text:
                '<think>Reasoning<think>nested<tool_call>junk</tool_call></think>Done',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        final reasoning = outputs
            .whereType<ModelReasoningDelta>()
            .map((output) => output.text)
            .join();
        expect(reasoning, contains('Reasoning'));
        final text = outputs
            .whereType<ModelTextDelta>()
            .map((output) => output.text)
            .join();
        expect(text, 'Done');
      });

      test('ignores unexpected tags inside tool call mode', () async {
        final parser = UniversalStreamParser(
          config: StreamParserConfig(
            toolCallExtractor: JsonToolCallExtractor(),
            tags: StreamTokenizer.defaultTags,
            supportsReasoning: true,
          ),
        );

        // Think tags + nested tool_call start inside tool call should be
        // ignored; content still extracted on the real </tool_call>.
        const chunks = [
          StreamChunk(
            text:
                '<tool_call><think></think><tool_call>{"name":"a","arguments":{}}</tool_call>',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();

        expect(outputs.whereType<ModelToolCallOutput>(), hasLength(1));
      });
    });

    group('custom tags', () {
      test('works with Mistral-style tags', () async {
        // When [TOOL_CALLS] is a tag, the tokenizer strips it and the
        // remaining content goes to the extractor. Use JsonToolCallExtractor
        // since the content is a raw JSON array.
        final parser = UniversalStreamParser(
          config: StreamParserConfig(
            toolCallExtractor: JsonToolCallExtractor(),
            tags: [
              const TagDefinition(
                tag: '[TOOL_CALLS]',
                type: StreamTokenType.toolStart,
              ),
            ],
            supportsReasoning: false,
          ),
        );

        const chunks = [
          StreamChunk(
            text:
                '[TOOL_CALLS] [{"name": "search", "arguments": {"q": "test"}}]',
            tokenCountDelta: 0,
          ),
        ];

        final outputs = parser.parseAll(chunks).toList();
        expect(outputs.whereType<ModelToolCallOutput>(), hasLength(1));
      });
    });

    group('Qwen 3 Coder XML tool calls', () {
      const qwen3CoderTags = <TagDefinition>[
        TagDefinition(
          tag: '<tool_call>',
          type: StreamTokenType.toolStart,
        ),
        TagDefinition(
          tag: '</tool_call>',
          type: StreamTokenType.toolEnd,
        ),
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
      ];

      UniversalStreamParser makeParser() => UniversalStreamParser(
        config: StreamParserConfig(
          toolCallExtractor: XmlToolCallExtractor(),
          tags: qwen3CoderTags,
          supportsReasoning: false,
        ),
      );

      test('wrapped tool call still extracts (regression)', () async {
        const body =
            '<tool_call>\n'
            '<function=list_files>\n'
            '<parameter=path>\n'
            '/home/joanna\n'
            '</parameter>\n'
            '</function>\n'
            '</tool_call>';

        const chunks = [
          StreamChunk(text: body, tokenCountDelta: 0),
        ];

        final outputs = makeParser()
            .parseAll(chunks, knownToolNames: {'list_files'})
            .toList();

        final call = outputs.whereType<ModelToolCallOutput>().single.call;
        expect(call.name, 'list_files');
        expect(call.arguments, {'path': '/home/joanna'});
      });

      test(
        'bare <function=…> without wrapper extracts when tool is registered',
        () async {
          const body =
              'Let me list the files.\n'
              '<function=list_files>\n'
              '<parameter=path>\n'
              '/home/joanna/Dropbox/Code/cow\n'
              '</parameter>\n'
              '</function>';

          const chunks = [
            StreamChunk(text: body, tokenCountDelta: 0),
          ];

          final outputs = makeParser()
              .parseAll(chunks, knownToolNames: {'list_files'})
              .toList();

          final textOutputs = outputs
              .whereType<ModelTextDelta>()
              .map((o) => o.text)
              .join();
          expect(textOutputs, 'Let me list the files.\n');

          final call = outputs.whereType<ModelToolCallOutput>().single.call;
          expect(call.name, 'list_files');
          expect(
            call.arguments,
            {'path': '/home/joanna/Dropbox/Code/cow'},
          );
        },
      );

      test(
        'bare <function=…> with unregistered name is re-emitted as text',
        () async {
          const body =
              '<function=unknown_fn>\n'
              '<parameter=x>\n'
              '1\n'
              '</parameter>\n'
              '</function>';

          const chunks = [
            StreamChunk(text: body, tokenCountDelta: 0),
          ];

          final outputs = makeParser()
              .parseAll(chunks, knownToolNames: {'list_files'})
              .toList();

          expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
          final text = outputs
              .whereType<ModelTextDelta>()
              .map((o) => o.text)
              .join();
          expect(text, contains('<function=unknown_fn>'));
          expect(text, contains('</function>'));
          expect(text, contains('<parameter=x>'));
        },
      );

      test(
        'bare <function=…> is treated as text when no tools are registered',
        () async {
          const body = 'Here is how it looks: <function=foo></function> — ok?';

          const chunks = [
            StreamChunk(text: body, tokenCountDelta: 0),
          ];

          final outputs = makeParser()
              .parseAll(chunks, knownToolNames: const <String>{})
              .toList();

          expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
          final text = outputs
              .whereType<ModelTextDelta>()
              .map((o) => o.text)
              .join();
          expect(text, body);
        },
      );

      test(
        'bare <function=…> is treated as text when knownToolNames is null',
        () async {
          const body = 'Syntax: <function=foo></function>';

          const chunks = [
            StreamChunk(text: body, tokenCountDelta: 0),
          ];

          final outputs = makeParser().parseAll(chunks).toList();

          expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
          final text = outputs
              .whereType<ModelTextDelta>()
              .map((o) => o.text)
              .join();
          expect(text, body);
        },
      );

      test('stream ending mid-function extracts buffered content', () async {
        // Model truncates before emitting the closing </function>.
        const body =
            '<function=list_files>\n'
            '<parameter=path>\n'
            '/tmp\n'
            '</parameter>';

        const chunks = [
          StreamChunk(text: body, tokenCountDelta: 0),
        ];

        final outputs = makeParser()
            .parseAll(chunks, knownToolNames: {'list_files'})
            .toList();

        final call = outputs.whereType<ModelToolCallOutput>().single.call;
        expect(call.name, 'list_files');
        expect(call.arguments, {'path': '/tmp'});
      });

      test(
        'stream ending mid-function with unknown name re-emits as text',
        () async {
          const body =
              '<function=unknown_fn>\n'
              '<parameter=x>\n'
              '1\n'
              '</parameter>';

          const chunks = [
            StreamChunk(text: body, tokenCountDelta: 0),
          ];

          final outputs = makeParser()
              .parseAll(chunks, knownToolNames: {'list_files'})
              .toList();

          expect(outputs.whereType<ModelToolCallOutput>(), isEmpty);
          final text = outputs
              .whereType<ModelTextDelta>()
              .map((o) => o.text)
              .join();
          expect(text, contains('<function=unknown_fn>'));
        },
      );

      test(
        'stray </function> in normal mode is yielded as text',
        () async {
          const body = 'Hello </function> world';

          const chunks = [
            StreamChunk(text: body, tokenCountDelta: 0),
          ];

          final outputs = makeParser()
              .parseAll(chunks, knownToolNames: {'list_files'})
              .toList();

          final text = outputs
              .whereType<ModelTextDelta>()
              .map((o) => o.text)
              .join();
          expect(text, 'Hello </function> world');
        },
      );

      test('wrapped call with unregistered name passes through', () async {
        // Wrapper tags are unambiguous intent: the call flows downstream
        // unfiltered so the registry can answer with a proper failure the
        // model can react to, instead of a silent drop.
        const body =
            '<tool_call>\n'
            '<function=unknown_fn>\n'
            '<parameter=x>\n'
            '1\n'
            '</parameter>\n'
            '</function>\n'
            '</tool_call>';

        const chunks = [
          StreamChunk(text: body, tokenCountDelta: 0),
        ];

        final outputs = makeParser()
            .parseAll(chunks, knownToolNames: {'list_files'})
            .toList();

        final call = outputs.whereType<ModelToolCallOutput>().single.call;
        expect(call.name, 'unknown_fn');
        expect(outputs.whereType<ModelTextDelta>(), isEmpty);
      });

      test(
        'token count deltas are emitted for all chunks '
        'including after tool calls',
        () async {
          const body =
              '<function=list_files>\n'
              '<parameter=path>\n'
              '/tmp\n'
              '</parameter>\n'
              '</function>';

          const chunks = [
            StreamChunk(text: 'Thinking...', tokenCountDelta: 3),
            StreamChunk(text: body, tokenCountDelta: 5),
            StreamChunk(text: 'trailing', tokenCountDelta: 7),
          ];

          final outputs = makeParser()
              .parseAll(chunks, knownToolNames: {'list_files'})
              .toList();

          final tokens = outputs
              .whereType<ModelTokensGenerated>()
              .map((o) => o.count)
              .toList();
          // All token deltas are emitted since processing continues after
          // tool calls.
          expect(tokens, [3, 5, 7]);
        },
      );
    });
  });
}
