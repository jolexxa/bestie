import 'dart:math';

import 'package:bestie_chat_view/src/state/models/write_access_choice.dart';
import 'package:bestie_chat_view/src/view/components/chat_input_row.dart';
import 'package:bestie_chat_view/src/view/components/write_access_prompt_row.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const _size = Size(80, 8);

const _ask = WriteAccessRequest(
  id: 'write-access-1',
  path: '/home/cow/.pub-cache',
  shownPath: '~/.pub-cache',
  reason: 'dart pub get needs to fill the package cache',
  agentId: 'primary',
);

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: ThemeEffects(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child,
          const Text('below'),
        ],
      ),
    ),
  ),
);

void main() {
  group('WriteAccessPromptRow', () {
    late int allowed;
    late int denied;

    setUp(() {
      allowed = 0;
      denied = 0;
    });

    Component row({WriteAccessChoice choice = WriteAccessChoice.deny}) =>
        WriteAccessPromptRow(
          request: _ask,
          choice: choice,
          onAllow: () => allowed++,
          onDeny: () => denied++,
          random: Random(1),
        );

    /// Where the label of the allow button starts, past its padding.
    const allowX = 2;

    /// Where the label of the deny button starts: past the allow button, its
    /// padding, and the gap.
    final denyX =
        allowX +
        WriteAccessPromptRow.allowLabel.length +
        2 +
        WriteAccessPromptRow.buttonGap.toInt() +
        2;
    const buttonY = 5;

    test('puts the question, the reason, the asker, and the answers', () async {
      await testNocterm('write access prompt', size: _size, (tester) async {
        await tester.pumpComponent(
          _themed(row()),
        );

        expect(tester.terminalState, containsText(WriteAccessPromptRow.title));
        expect(tester.terminalState, containsText('write to ~/.pub-cache'));
        expect(tester.terminalState, containsText('normal agent operations?'));
        expect(tester.terminalState, containsText('Reason: dart pub get'));
        expect(tester.terminalState, containsText('Asked by: the main agent'));
        expect(
          tester.terminalState,
          containsText(WriteAccessPromptRow.allowLabel),
        );
        expect(
          tester.terminalState,
          containsText(WriteAccessPromptRow.denyLabel),
        );
      });
    });

    test('sets the title in the error colors on a glitter bar', () async {
      await testNocterm('write access bar', size: _size, (tester) async {
        await tester.pumpComponent(
          _themed(row()),
        );

        final title = tester.terminalState.getCellAt(
          WriteAccessPromptRow.inset + 1,
          0,
        );
        expect(title?.char, '⛨');
        expect(title?.style.color, appThemeDefault.onError);
        expect(title?.style.backgroundColor, appThemeDefault.error);
        final glitter = tester.terminalState.getCellAt(
          _size.width.toInt() - 1,
          0,
        );
        expect(glitter?.char, glitterGlyphs.first);
        expect(glitter?.style.backgroundColor, appThemeDefault.error);
      });
    });

    test("takes the text field's room", () async {
      await testNocterm('write access height', size: _size, (tester) async {
        await tester.pumpComponent(
          _themed(row()),
        );

        expect(
          tester.terminalState.getCellAt(0, ChatInputRow.height.toInt())?.char,
          'b',
        );
      });
    });

    test('fills the answer focus rests on', () async {
      await testNocterm('write access focus', size: _size, (tester) async {
        await tester.pumpComponent(_themed(row()));
        final deny = tester.terminalState.getCellAt(denyX, buttonY);
        expect(deny?.char, 'n');
        expect(deny?.style.backgroundColor, appThemeDefault.primary);
        final allow = tester.terminalState.getCellAt(allowX, buttonY);
        expect(allow?.char, 'y');
        expect(allow?.style.color, appThemeDefault.error);
        expect(allow?.style.backgroundColor, isNot(appThemeDefault.error));

        await tester.pumpComponent(
          _themed(row(choice: WriteAccessChoice.allow)),
        );

        expect(
          tester.terminalState
              .getCellAt(allowX, buttonY)
              ?.style
              .backgroundColor,
          appThemeDefault.error,
        );
        expect(
          tester.terminalState.getCellAt(denyX, buttonY)?.style.backgroundColor,
          isNot(appThemeDefault.primary),
        );
      });
    });

    test('a click on an answer gives it', () async {
      await testNocterm('write access click', size: _size, (tester) async {
        await tester.pumpComponent(_themed(row()));

        await tester.tap(allowX, buttonY);
        expect(allowed, 1);
        expect(denied, 0);

        await tester.tap(denyX, buttonY);
        expect(denied, 1);
      });
    });

    test('names a subagent as the asker', () {
      expect(
        WriteAccessPromptRow.askerFor(
          const WriteAccessRequest(
            id: 'write-access-2',
            path: '/home/cow/.cargo',
            shownPath: '~/.cargo',
            reason: 'cargo build',
            agentId: 'subagent-1',
          ),
        ),
        'a subagent',
      );
    });
  });
}
