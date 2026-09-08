import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// Wide enough for the frame's right edge to sit clear of the body.
const _pane = Size(20, 5);

final _titleStyle = TextStyle(
  color: appThemeDefault.success,
  fontWeight: FontWeight.bold,
);

Component _frame({Color? frameColor, String gutterGlyph = '┃'}) => TuiTheme(
  data: appThemeDefault,
  child: SizedBox(
    width: _pane.width,
    height: _pane.height,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TitledFrame(
          title: 'You',
          titleStyle: _titleStyle,
          gutterGlyph: gutterGlyph,
          gutterColor: appThemeDefault.primary,
          frameColor: frameColor,
          child: const Text('body'),
        ),
      ],
    ),
  ),
);

String _charAt(NoctermTester tester, int x, int y) =>
    tester.terminalState.getCellAt(x, y)?.char ?? '';

/// Restyles the frame in place, so the same render object gets repainted.
class _Restyle extends StatefulComponent {
  const _Restyle({super.key});

  @override
  State<_Restyle> createState() => _RestyleState();
}

class _RestyleState extends State<_Restyle> {
  var _title = 'You';
  TextStyle _titleStyle = _titleStyle0;
  var _gutterGlyph = '┃';
  Color _gutterColor = appThemeDefault.primary;
  Color? _frameColor;

  static final _titleStyle0 = TextStyle(color: appThemeDefault.success);

  void restyle() => setState(() {
    _title = 'Me';
    _titleStyle = TextStyle(color: appThemeDefault.info);
    _gutterGlyph = '│';
    _gutterColor = appThemeDefault.muted;
    _frameColor = appThemeDefault.error;
  });

  @override
  Component build(BuildContext context) => TuiTheme(
    data: appThemeDefault,
    child: SizedBox(
      width: _pane.width,
      height: _pane.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitledFrame(
            title: _title,
            titleStyle: _titleStyle,
            gutterGlyph: _gutterGlyph,
            gutterColor: _gutterColor,
            frameColor: _frameColor,
            child: const Text('body'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('TitledFrame', () {
    test('heads the body with the title, both inset by the rim', () async {
      await testNocterm('titled frame layout', (tester) async {
        await tester.pumpComponent(_frame());

        expect(_charAt(tester, 2, 0), 'Y');
        expect(_charAt(tester, 2, 1), 'b');
        expect(
          tester.terminalState.getCellAt(2, 0)?.style.fontWeight,
          FontWeight.bold,
        );
      }, size: _pane);
    });

    test('runs the gutter glyph beside the title and body only', () async {
      await testNocterm('titled frame gutter', (tester) async {
        await tester.pumpComponent(_frame());

        expect(_charAt(tester, 0, 0), '┃');
        expect(_charAt(tester, 0, 1), '┃');
        expect(_charAt(tester, 0, 2), ' ');
        expect(
          tester.terminalState.getCellAt(0, 1)?.style.color,
          appThemeDefault.primary,
        );
      }, size: _pane);
    });

    test('a blank gutter glyph still keeps the rim', () async {
      await testNocterm('titled frame blank gutter', (tester) async {
        await tester.pumpComponent(_frame(gutterGlyph: ' '));

        expect(_charAt(tester, 0, 0), ' ');
        expect(_charAt(tester, 2, 1), 'b');
      }, size: _pane);
    });

    test(
      'boxes the block in the frame color with the title in the top rule',
      () async {
        await testNocterm('titled frame boxed', (tester) async {
          await tester.pumpComponent(_frame(frameColor: appThemeDefault.error));

          expect(_charAt(tester, 0, 0), '┏');
          expect(_charAt(tester, 19, 0), '┓');
          expect(_charAt(tester, 0, 1), '┃');
          expect(_charAt(tester, 19, 1), '┃');
          expect(_charAt(tester, 0, 2), '┗');
          expect(_charAt(tester, 19, 2), '┛');
          expect(_charAt(tester, 6, 0), '━');
          expect(
            tester.terminalState.getCellAt(0, 0)?.style.color,
            appThemeDefault.error,
          );
          expect(_charAt(tester, 1, 0), ' ');
          expect(_charAt(tester, 2, 0), 'Y');
          expect(_charAt(tester, 5, 0), ' ');
        }, size: _pane);
      },
    );

    test('repaints in place when restyled', () async {
      await testNocterm('titled frame restyle', (tester) async {
        final key = GlobalKey<_RestyleState>();
        await tester.pumpComponent(_Restyle(key: key));
        expect(_charAt(tester, 2, 0), 'Y');

        key.currentState!.restyle();
        await tester.pump();
        // Restyling to the same look again must be a quiet no-op.
        key.currentState!.restyle();
        await tester.pump();

        expect(_charAt(tester, 2, 0), 'M');
        expect(
          tester.terminalState.getCellAt(2, 0)?.style.color,
          appThemeDefault.info,
        );
        expect(_charAt(tester, 0, 0), '┏');
        expect(
          tester.terminalState.getCellAt(0, 0)?.style.color,
          appThemeDefault.error,
        );
      }, size: _pane);
    });

    test('the body sits in the same cells boxed or not', () async {
      await testNocterm('titled frame footprint', (tester) async {
        await tester.pumpComponent(_frame());
        expect(_charAt(tester, 2, 1), 'b');
        expect(_charAt(tester, 5, 1), 'y');

        await tester.pumpComponent(_frame(frameColor: appThemeDefault.error));
        expect(_charAt(tester, 2, 1), 'b');
        expect(_charAt(tester, 5, 1), 'y');
      }, size: _pane);
    });
  });
}
