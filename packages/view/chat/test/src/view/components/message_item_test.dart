import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/message_item.dart';
import 'package:bestie_chat_view/src/view/components/message_item_layout.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

TranscriptParagraphBlock _para(String text) =>
    TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: text);

MessageTimelineItem _message({
  Role role = Role.assistant,
  List<TranscriptBlock> blocks = const [],
  bool running = false,
}) => MessageTimelineItem(
  id: 'msg-1',
  role: role,
  timestamp: DateTime.utc(2026),
  responseId: 0,
  blocks: blocks,
  running: running,
);

/// The one-cell slot a running row spins in, between the two spacer columns.
const int _gutterColumn = 1;

/// The first column of the rim around the sender and body.
const int _rimColumn = 3;

/// The column the sender label and body start in.
const int _bodyColumn = 5;

void main() {
  group('MessageItem', () {
    test('boxes an alert message in the error color', () async {
      await testNocterm('alert box', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageItem(
              item: _message(role: Role.user, blocks: [_para('again')]),
              frame: MessageFrame.alert,
            ),
          ),
        );

        final corner = tester.terminalState.getCellAt(_rimColumn, 0);
        expect(corner?.char, '┏');
        expect(corner?.style.color, appThemeDefault.error);
        expect(tester.terminalState, containsText('again'));
      });
    });

    test('boxes a subtle message in the muted color', () async {
      await testNocterm('subtle box', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageItem(
              item: _message(role: Role.user, blocks: [_para('again')]),
              frame: MessageFrame.subtle,
            ),
          ),
        );

        final corner = tester.terminalState.getCellAt(_rimColumn, 0);
        expect(corner?.char, '┏');
        expect(corner?.style.color, appThemeDefault.muted);
      });
    });

    test('keeps the body in place boxed or not', () async {
      await testNocterm('alert footprint', (tester) async {
        final plain = _message(role: Role.user, blocks: [_para('again')]);

        await tester.pumpComponent(_themed(MessageItem(item: plain)));
        expect(tester.terminalState.getCellAt(_bodyColumn, 1)?.char, 'a');

        await tester.pumpComponent(
          _themed(MessageItem(item: plain, frame: MessageFrame.alert)),
        );
        expect(tester.terminalState.getCellAt(_bodyColumn, 1)?.char, 'a');
      });
    });

    test('renders the answer text under the Bestie sender', () async {
      await testNocterm('assistant answer', (tester) async {
        await tester.pumpComponent(
          _themed(MessageItem(item: _message(blocks: [_para('the answer')]))),
        );

        expect(tester.terminalState, containsText('Bestie'));
        expect(tester.terminalState, containsText('the answer'));
      });
    });

    test('spins the gutter while the answer is running', () async {
      await testNocterm('running gutter', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageItem(
              item: _message(blocks: [_para('the answer')], running: true),
            ),
          ),
        );

        // The spinner opens on a blank frame, so it is its color that marks
        // the gutter as occupied rather than any one glyph.
        expect(
          tester.terminalState.getCellAt(_gutterColumn, 0)?.style.color,
          appThemeDefault.secondary,
        );
      });
    });

    test('leaves the gutter empty once the answer settles', () async {
      await testNocterm('settled gutter', (tester) async {
        await tester.pumpComponent(
          _themed(MessageItem(item: _message(blocks: [_para('the answer')]))),
        );

        expect(
          tester.terminalState.getCellAt(_gutterColumn, 0)?.style.color,
          isNull,
        );
      });
    });

    test('holds half-written math back while the answer is running', () async {
      await testNocterm('streaming math', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageItem(
              item: _message(blocks: [_para(r'so \(x^2')], running: true),
            ),
          ),
        );

        expect(tester.terminalState, containsText('so …'));
      });
    });

    test('shows half-written math verbatim once the answer settles', () async {
      await testNocterm('settled math', (tester) async {
        await tester.pumpComponent(
          _themed(MessageItem(item: _message(blocks: [_para(r'so \(x^2')]))),
        );

        expect(tester.terminalState, containsText(r'so \(x^2'));
      });
    });

    test('renders a user message under the You sender', () async {
      await testNocterm('user message', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageItem(
              item: _message(role: Role.user, blocks: [_para('my question')]),
            ),
          ),
        );

        expect(tester.terminalState, containsText('You'));
        expect(tester.terminalState, containsText('my question'));
      });
    });

    test('renders a no-content row when there are no paragraphs', () async {
      await testNocterm('empty message', (tester) async {
        await tester.pumpComponent(_themed(MessageItem(item: _message())));

        expect(tester.terminalState, containsText('(no content)'));
      });
    });

    test('split paragraph blocks rejoin verbatim across a fence', () async {
      // The lexer may split one passage across paragraph blocks, even inside
      // a code fence; rendering each block separately would break the fence.
      await testNocterm('split paragraph blocks', (tester) async {
        await tester.pumpComponent(
          _themed(
            MessageItem(
              item: _message(
                blocks: [_para('```dart\n'), _para('final x = 1;\n```')],
              ),
            ),
          ),
        );

        expect(tester.terminalState, containsText('final x = 1;'));
        expect(tester.terminalState, isNot(containsText('```')));
      });
    });
  });
}
