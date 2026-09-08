import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// Narrow enough that a value of any length has to be measured against it,
/// and tall enough that a stacked row never runs out of pane to stack into.
const _pane = Size(40, 8);

Component _row({
  required String label,
  required String value,
  bool highlighted = false,
}) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: SizedBox(
      width: _pane.width,
      height: _pane.height,
      child: DetailRow(label: label, value: value, highlighted: highlighted),
    ),
  ),
);

/// The rows the component actually drew on, in order, stripped of the rail
/// every row is inset by.
List<String> _drawn(NoctermTester tester) => tester.terminalState
    .getText()
    .split('\n')
    .map((row) => row.trim())
    .where((row) => row.isNotEmpty)
    .toList();

void main() {
  group('DetailRow pairs a label with its value', () {
    // Spending three rows on `path` / `a.dart` / blank is most of why a
    // detail table outgrows the pane it sits in.
    test('puts a short label and a short value on one row', () async {
      await testNocterm('detail row paired', (tester) async {
        await tester.pumpComponent(_row(label: 'path', value: 'a.dart'));

        expect(_drawn(tester), hasLength(1));
        expect(tester.terminalState, containsText('path'));
        expect(tester.terminalState, containsText('a.dart'));
      }, size: _pane);
    });

    test('lines every value up at the same column', () async {
      await testNocterm('detail row column', (tester) async {
        await tester.pumpComponent(_row(label: 'a', value: 'first'));
        final short = _drawn(tester).single.indexOf('first');

        await tester.pumpComponent(_row(label: 'a-longer', value: 'first'));

        expect(_drawn(tester).single.indexOf('first'), short);
      }, size: _pane);
    });
  });

  group('DetailRow stacks when the pair will not fit', () {
    test('stacks a value too wide to share the row', () async {
      await testNocterm('detail row wide value', (tester) async {
        await tester.pumpComponent(_row(label: 'command', value: 'x' * 60));

        final drawn = _drawn(tester);
        expect(drawn.first, 'command');
        expect(
          drawn.skip(1).join(),
          'x' * 60,
          reason: 'a stacked value wraps rather than being cut to fit',
        );
      }, size: _pane);
    });

    test('stacks a label too wide to leave room for a value', () async {
      await testNocterm('detail row wide label', (tester) async {
        await tester.pumpComponent(
          _row(label: 'a-very-long-label-indeed', value: 'v'),
        );

        expect(_drawn(tester), ['a-very-long-label-indeed', 'v']);
      }, size: _pane);
    });

    // A value carrying its own breaks has no business being folded onto one
    // row beside its label — it would read as a single line and lie.
    test('stacks a multi-line value', () async {
      await testNocterm('detail row multiline', (tester) async {
        await tester.pumpComponent(
          _row(label: 'command', value: 'one\ntwo\nthree'),
        );

        expect(_drawn(tester), ['command', 'one', 'two', 'three']);
      }, size: _pane);
    });

    test('drops the label entirely when there is none', () async {
      await testNocterm('detail row unlabelled', (tester) async {
        await tester.pumpComponent(_row(label: '', value: 'bare'));

        expect(_drawn(tester), ['bare']);
      }, size: _pane);
    });
  });

  test('DetailRow paints a zebra stripe only when highlighted', () async {
    await testNocterm('detail row zebra', (tester) async {
      await tester.pumpComponent(
        _row(label: 'path', value: 'a.dart', highlighted: true),
      );
      final striped = tester.terminalState
          .getCellAt(0, 0)
          ?.style
          .backgroundColor;

      await tester.pumpComponent(_row(label: 'path', value: 'a.dart'));

      expect(
        striped,
        isNot(tester.terminalState.getCellAt(0, 0)?.style.backgroundColor),
      );
    }, size: _pane);
  });
}
