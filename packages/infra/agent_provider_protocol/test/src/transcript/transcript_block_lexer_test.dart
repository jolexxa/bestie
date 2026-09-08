import 'package:agent_provider_protocol/agent_provider_protocol.dart' as agent;
import 'package:agent_provider_protocol/src/transcript/transcript_block_lexer.dart'
    as internal;
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('TranscriptBlockLexer', () {
    test('returns no blocks for empty text', () {
      const lexer = internal.TranscriptBlockLexer();

      expect(lexer.paragraphs(''), isEmpty);
    });

    test('creates a single paragraph block for a single line', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory(['0192f6e4-0000-7000-8000-000000000101']),
      );

      final blocks = lexer.paragraphs('hello');

      expect(blocks, hasLength(1));
      expect(blocks.single.text, 'hello');
      expect(
        blocks.single.id.value.uuid,
        '0192f6e4-0000-7000-8000-000000000101',
      );
    });

    test('splits paragraph blocks at line boundaries', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000111',
          '0192f6e4-0000-7000-8000-000000000112',
        ]),
      );

      final blocks = lexer.paragraphs('hello\nworld');

      expect(blocks.map((block) => block.text), ['hello\n', 'world']);
    });

    test('keeps trailing newlines on the preceding block', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory(['0192f6e4-0000-7000-8000-000000000121']),
      );

      final blocks = lexer.paragraphs('hello\n\n');

      expect(blocks.map((block) => block.text), ['hello\n\n']);
    });

    test('attaches blank lines to the previous block', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000131',
          '0192f6e4-0000-7000-8000-000000000132',
        ]),
      );

      final blocks = lexer.paragraphs('hello\n\nworld');

      expect(blocks.map((block) => block.text), ['hello\n\n', 'world']);
    });

    test('handles CRLF and CR line endings', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000141',
          '0192f6e4-0000-7000-8000-000000000142',
          '0192f6e4-0000-7000-8000-000000000143',
        ]),
      );

      final blocks = lexer.paragraphs('a\r\nb\rc');

      expect(blocks.map((block) => block.text), ['a\r\n', 'b\r', 'c']);
    });

    test('hard-splits blocks at maxBlockLength graphemes', () {
      final lexer = internal.TranscriptBlockLexer(
        maxBlockLength: 2,
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000151',
          '0192f6e4-0000-7000-8000-000000000152',
          '0192f6e4-0000-7000-8000-000000000153',
        ]),
      );

      final blocks = lexer.paragraphs('abcde');

      expect(blocks.map((block) => block.text), ['ab', 'cd', 'e']);
    });

    test('does not split grapheme clusters', () {
      final lexer = internal.TranscriptBlockLexer(
        maxBlockLength: 1,
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000171',
          '0192f6e4-0000-7000-8000-000000000172',
          '0192f6e4-0000-7000-8000-000000000173',
        ]),
      );

      final blocks = lexer.paragraphs('a👍🏽e\u0301');

      expect(blocks.map((block) => block.text), ['a', '👍🏽', 'e\u0301']);
    });

    test('creates reasoning and tool output block types', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000161',
          '0192f6e4-0000-7000-8000-000000000162',
        ]),
      );

      expect(
        lexer.reasoning('plan').single,
        isA<agent.TranscriptReasoningBlock>(),
      );
      expect(
        lexer.toolOutput('output').single,
        isA<agent.TranscriptToolOutputBlock>(),
      );
    });

    test('maps delta spans onto block stats by char range', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000191',
          '0192f6e4-0000-7000-8000-000000000192',
        ]),
      );
      final t0 = DateTime.utc(2025);
      final t1 = t0.add(const Duration(milliseconds: 100));
      final spans = [
        internal.DeltaSpan(start: 0, end: 6, timestamp: t0)..tokens = 3,
        internal.DeltaSpan(start: 6, end: 11, timestamp: t1)..tokens = 2,
      ];

      final blocks = lexer.paragraphs('hello\nworld', spans: spans);

      expect(blocks, hasLength(2));
      expect(
        blocks[0].stat,
        agent.BlockStat(startedAt: t0, endedAt: t0, tokenCount: 3),
      );
      expect(
        blocks[1].stat,
        agent.BlockStat(startedAt: t1, endedAt: t1, tokenCount: 2),
      );
    });

    test(
      'attributes a boundary-crossing span to the block containing its start',
      () {
        final lexer = internal.TranscriptBlockLexer(
          maxBlockLength: 2,
          idFactory: _idFactory([
            '0192f6e4-0000-7000-8000-0000000001a1',
            '0192f6e4-0000-7000-8000-0000000001a2',
          ]),
        );
        final t0 = DateTime.utc(2025);
        final t1 = t0.add(const Duration(milliseconds: 50));
        final spans = [
          internal.DeltaSpan(start: 0, end: 1, timestamp: t0)..tokens = 1,
          internal.DeltaSpan(start: 1, end: 4, timestamp: t1)..tokens = 4,
        ];

        final blocks = lexer.paragraphs('abcd', spans: spans);

        expect(
          blocks[0].stat,
          agent.BlockStat(startedAt: t0, endedAt: t1, tokenCount: 5),
        );
        expect(blocks[1].stat, agent.BlockStat(startedAt: t1, endedAt: t1));
      },
    );

    test('leaves stats null without spans or coverage', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-0000000001b1',
          '0192f6e4-0000-7000-8000-0000000001b2',
          '0192f6e4-0000-7000-8000-0000000001b3',
        ]),
      );
      final t0 = DateTime.utc(2025);

      expect(lexer.paragraphs('hello').single.stat, isNull);
      final blocks = lexer.paragraphs(
        'hello\ntail',
        spans: [internal.DeltaSpan(start: 0, end: 6, timestamp: t0)],
      );
      expect(blocks[0].stat, agent.BlockStat(startedAt: t0, endedAt: t0));
      expect(blocks[1].stat, isNull);
    });

    test('lex dispatches to the requested text block kind', () {
      final lexer = internal.TranscriptBlockLexer(
        idFactory: _idFactory([
          '0192f6e4-0000-7000-8000-000000000181',
          '0192f6e4-0000-7000-8000-000000000182',
          '0192f6e4-0000-7000-8000-000000000183',
        ]),
      );

      expect(
        lexer
            .lex(
              text: 'paragraph',
              kind: internal.TranscriptTextBlockKind.paragraph,
            )
            .single,
        isA<agent.TranscriptParagraphBlock>(),
      );
      expect(
        lexer
            .lex(
              text: 'reasoning',
              kind: internal.TranscriptTextBlockKind.reasoning,
            )
            .single,
        isA<agent.TranscriptReasoningBlock>(),
      );
      expect(
        lexer
            .lex(
              text: 'output',
              kind: internal.TranscriptTextBlockKind.toolOutput,
            )
            .single,
        isA<agent.TranscriptToolOutputBlock>(),
      );
    });

    group('lexEntry', () {
      agent.TranscriptEntry entry(
        agent.Role role,
        List<agent.TranscriptBlock> blocks,
      ) => agent.TranscriptEntry(
        id: agent.TranscriptEntryId.v7(),
        role: role,
        blocks: blocks,
      );

      test('splits assistant paragraphs and reasoning by line', () {
        const lexer = internal.TranscriptBlockLexer();
        final stat = agent.BlockStat(
          startedAt: DateTime.utc(2025),
          endedAt: DateTime.utc(2025, 1, 1, 0, 0, 1),
        );
        final source = entry(agent.Role.assistant, [
          agent.TranscriptParagraphBlock(
            id: agent.TranscriptBlockId.v7(),
            text: 'one\ntwo',
            stat: stat,
          ),
          agent.TranscriptReasoningBlock(
            id: agent.TranscriptBlockId.v7(),
            text: 'think\nmore',
          ),
        ]);

        final lexed = lexer.lexEntry(source);

        expect(lexed.id, source.id);
        expect(lexed.blocks, hasLength(4));
        expect(lexed.blocks[0], isA<agent.TranscriptParagraphBlock>());
        expect((lexed.blocks[0] as agent.TranscriptParagraphBlock).stat, stat);
        expect(lexed.blocks[2], isA<agent.TranscriptReasoningBlock>());
      });

      test('leaves single-line assistant entries as they are', () {
        const lexer = internal.TranscriptBlockLexer();
        final source = entry(agent.Role.assistant, [
          agent.TranscriptParagraphBlock(
            id: agent.TranscriptBlockId.v7(),
            text: 'one line',
          ),
          agent.TranscriptToolCallBlock(
            id: agent.TranscriptBlockId.v7(),
            toolCall: const agent.ToolCallDefault(
              id: 'call',
              name: 'tool',
              arguments: {},
            ),
          ),
        ]);

        expect(lexer.lexEntry(source), same(source));
      });

      test('never touches other roles', () {
        const lexer = internal.TranscriptBlockLexer();
        final source = entry(agent.Role.user, [
          agent.TranscriptParagraphBlock(
            id: agent.TranscriptBlockId.v7(),
            text: 'one\ntwo',
          ),
        ]);

        expect(lexer.lexEntry(source), same(source));
      });
    });
  });
}

agent.TranscriptBlockIdFactory _idFactory(List<String> ids) {
  var index = 0;
  return () => agent.TranscriptBlockId(UuidValue.raw(ids[index++]));
}
