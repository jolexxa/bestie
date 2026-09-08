import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 20, height: 3, child: child),
    ),
  ),
);

void main() {
  group('AppButton', () {
    test('renders its label inside a border', () async {
      await testNocterm('app button', (tester) async {
        await tester.pumpComponent(
          _themed(AppButton(label: '↵ Install', onPressed: () {})),
        );
        expect(tester.terminalState, containsText('↵ Install'));
        // A box border draws corner glyphs around the label.
        expect(tester.terminalState, containsText('┌'));
      });
    });

    test('fills when selected, as when hovered', () async {
      await testNocterm('app button selected', (tester) async {
        await tester.pumpComponent(
          _themed(AppButton(label: 'Go', onPressed: () {}, selected: true)),
        );
        final label = tester.terminalState.getCellAt(3, 1);
        expect(label?.char, 'G');
        expect(label?.style.color, appThemeDefault.onPrimary);
        expect(label?.style.backgroundColor, appThemeDefault.primary);
      });
    });

    test('fills on hover in the colors it is given', () async {
      await testNocterm('app button hover', (tester) async {
        await tester.pumpComponent(
          _themed(
            AppButton(
              label: 'Go',
              onPressed: () {},
              color: appThemeDefault.error,
              onColor: appThemeDefault.onError,
            ),
          ),
        );
        expect(
          tester.terminalState.getCellAt(3, 1)?.style.color,
          appThemeDefault.error,
        );

        await tester.hover(3, 1);

        final label = tester.terminalState.getCellAt(3, 1);
        expect(label?.style.color, appThemeDefault.onError);
        expect(label?.style.backgroundColor, appThemeDefault.error);
      });
    });

    test('dense takes one row with no border', () async {
      await testNocterm('app button dense', (tester) async {
        await tester.pumpComponent(
          _themed(AppButton(label: 'Go', onPressed: () {}, dense: true)),
        );
        expect(tester.terminalState.getCellAt(2, 0)?.char, 'G');
        expect(tester.terminalState, isNot(containsText('┌')));
      });
    });

    test('invokes onPressed when clicked', () async {
      await testNocterm('app button click', (tester) async {
        var pressed = 0;
        await tester.pumpComponent(
          _themed(AppButton(label: 'Go', onPressed: () => pressed++)),
        );
        // Click inside the button box: border row 0, label row 1, and
        // the label sits past the left border + horizontal padding.
        await tester.tap(3, 1);
        expect(pressed, 1);
      });
    });
  });
}
