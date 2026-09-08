import 'package:bestie_chat_view/src/view/components/timeline_marker.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

const _label = TextSpan(text: 'Marker');

/// The row the marker sits on and the column where its label starts.
final class _LabelPosition {
  _LabelPosition.of(NoctermTester tester)
    : this._(tester.terminalState.getText().split('\n'));

  _LabelPosition._(List<String> lines)
    : row = lines.indexWhere((line) => line.contains('Marker')),
      column = lines
          .firstWhere((line) => line.contains('Marker'))
          .indexOf('Marker');

  final int row;
  final int column;
}

void main() {
  group('TimelineMarker', () {
    test('draws the label inset in outline rules, leaving its style', () async {
      await testNocterm('timeline marker idle', (tester) async {
        await tester.pumpComponent(
          _themed(const TimelineMarker(label: _label, selected: false)),
        );
        expect(tester.terminalState, containsText('Marker'));
        final at = _LabelPosition.of(tester);
        final label = tester.terminalState.getCellAt(at.column, at.row);
        expect(label?.style.color, isNot(appThemeDefault.warning));
        expect(label?.style.fontWeight, isNot(FontWeight.bold));
        final rule = tester.terminalState.getCellAt(0, at.row);
        expect(rule?.style.backgroundColor, appThemeDefault.outline);
      });
    });

    test('brightens the rules when hovered', () async {
      await testNocterm('timeline marker hovered', (tester) async {
        await tester.pumpComponent(
          _themed(
            const TimelineMarker(label: _label, selected: false, hovered: true),
          ),
        );
        final at = _LabelPosition.of(tester);
        final rule = tester.terminalState.getCellAt(0, at.row);
        expect(rule?.style.backgroundColor, appThemeDefault.muted);
        final label = tester.terminalState.getCellAt(at.column, at.row);
        expect(label?.style.fontWeight, isNot(FontWeight.bold));
      });
    });

    test('turns the rules primary and the label bold when selected', () async {
      await testNocterm('timeline marker selected', (tester) async {
        await tester.pumpComponent(
          _themed(const TimelineMarker(label: _label, selected: true)),
        );
        final at = _LabelPosition.of(tester);
        final label = tester.terminalState.getCellAt(at.column, at.row);
        expect(label?.style.color, isNot(appThemeDefault.warning));
        expect(label?.style.fontWeight, FontWeight.bold);
        final rule = tester.terminalState.getCellAt(0, at.row);
        expect(rule?.style.backgroundColor, appThemeDefault.primary);
      });
    });

    test("keeps a segment's own color when selected", () async {
      await testNocterm('timeline marker segment color', (tester) async {
        await tester.pumpComponent(
          _themed(
            TimelineMarker(
              label: TextSpan(
                children: [
                  TextSpan(
                    text: '●',
                    style: TextStyle(color: appThemeDefault.success),
                  ),
                  const TextSpan(text: ' Marker'),
                ],
              ),
              selected: true,
            ),
          ),
        );
        final at = _LabelPosition.of(tester);
        final glyph = tester.terminalState.getCellAt(at.column - 2, at.row);
        expect(glyph?.char, '●');
        expect(glyph?.style.color, appThemeDefault.success);
      });
    });

    test('renders the body beneath the rule', () async {
      await testNocterm('timeline marker body', (tester) async {
        await tester.pumpComponent(
          _themed(
            const TimelineMarker(
              label: _label,
              selected: false,
              body: Text('underneath'),
            ),
          ),
        );
        final text = tester.terminalState.getText();
        expect(text.indexOf('Marker'), lessThan(text.indexOf('underneath')));
      });
    });
  });
}
