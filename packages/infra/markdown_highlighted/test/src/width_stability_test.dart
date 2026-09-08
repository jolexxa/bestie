import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// The pane widths a chat splitter drags between.
const int _narrow = 29;
const int _wide = 52;

/// A highlight theme with a backdrop, the shape bestie derives from its app
/// theme. A backdrop is what turns on code-block padding — the stock
/// [HighlightTheme.dracula] has none and would skip the path under test.
const HighlightTheme _backedTheme = HighlightTheme(
  styles: {},
  background: Color(0xFF282A36),
);

/// The selectable text of each block in [data] rendered at [maxWidth] —
/// the exact strings selection char indexes point into, one per selectable.
List<String> _blockTextsAt(String data, int maxWidth) {
  final nodes = buildMarkdownDocument().parse(data);
  final visitor = MarkdownVisitor(
    theme: MarkdownTheme.terminal(),
    builders: MarkdownBuilders.defaults(theme: _backedTheme),
    maxWidth: maxWidth,
    codeBlockBackground: _backedTheme.background,
  );
  return [
    for (final block in visitor.visit(nodes))
      switch (block) {
        ProseBlock(:final span) ||
        CodeBlock(:final span) ||
        MathBlock(:final span) ||
        TableBlock(:final span) => _flatten(span),
        RuleBlock() => '',
      },
  ];
}

String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

/// The whole document's selectable text at [maxWidth], blocks joined the way
/// they read.
String _plainTextAt(String data, int maxWidth) =>
    _blockTextsAt(data, maxWidth).join('\n\n');

const String _codeDocument = '''
Intro prose.

```dart
final x = 1;
final y = 2;
```

The needle sits here.
''';

/// One logical code line wider than the narrow pane but not the wide one,
/// so only the narrow layout has to soft-wrap it.
const String _longLineDocument = '''
```dart
const greeting = 'hello from a longer line';
```

The needle sits here.
''';

const String _ruleDocument = '''
Above the rule.

---

The needle sits here.
''';

const String _mathDocument = r'''
Above the math.

$$
E = mc^2
$$

The needle sits here.
''';

const String _tableDocument = '''
| a | b |
| - | - |
| 1 | 2 |

The needle sits here.
''';

/// Selection edges are character indexes into the flattened text. A pane
/// resize re-parses at the new width; any construct that bakes the width
/// into its text shifts every index after it, and a held selection slides
/// onto different words. So: layout may depend on width, selectable text
/// may not.
void main() {
  group('selectable text is width-independent', () {
    const cases = {
      'a fenced code block': _codeDocument,
      'a code line wider than the pane': _longLineDocument,
      'a horizontal rule': _ruleDocument,
      'a display math block': _mathDocument,
    };

    for (final MapEntry(key: name, value: document) in cases.entries) {
      test('$name flattens identically at $_narrow and $_wide columns', () {
        // Per selectable block — the strings selection indexes live in —
        // and for the document as a whole.
        expect(
          _blockTextsAt(document, _narrow),
          _blockTextsAt(document, _wide),
        );
        expect(
          _plainTextAt(document, _narrow),
          _plainTextAt(document, _wide),
        );
      });
    }

    test('a table that fits keeps its natural width at any pane size', () {
      // Lock-in: fitting tables already render from natural column widths.
      // (An overflowing table redistributes columns and is consciously
      // width-dependent — box-drawing is its content, not decoration.)
      expect(
        _plainTextAt(_tableDocument, _narrow),
        _plainTextAt(_tableDocument, _wide),
      );
    });

    test('prose below a code block keeps its character offset', () {
      // The symptom as reported: the selection keeps its length but slides
      // to different text, because the padded block above it grew.
      final narrow = _plainTextAt(_codeDocument, _narrow);
      final wide = _plainTextAt(_codeDocument, _wide);
      expect(narrow.indexOf('needle'), wide.indexOf('needle'));
    });

    test('code block selectable text is the raw code', () {
      // Copying a selection must yield the code, not the code plus a
      // backdrop's worth of trailing spaces on every line.
      expect(
        _plainTextAt(_codeDocument, _wide),
        contains('final x = 1;\nfinal y = 2;'),
      );
    });
  });

  group('selection across a reflow', () {
    test('a held selection below a code block survives a resize', () async {
      await testNocterm('markdown selection reflow', (tester) async {
        final changes = <String>[];
        final viewKey = GlobalKey();
        final key = GlobalKey<_ResizeHarnessState>();
        await tester.pumpComponent(
          _ResizeHarness(
            key: key,
            viewKey: viewKey,
            onSelectionChanged: changes.add,
          ),
        );

        // Rows: two code lines, the one-row block gap, then the prose on
        // row 3. Every line fits both widths, so the prose row never moves
        // through the resize.
        await tester.press(0, 3);
        await tester.sendMouseEvent(
          const MouseEvent(
            button: MouseButton.left,
            x: 21,
            y: 3,
            pressed: true,
            isMotion: true,
          ),
        );
        await tester.release(21, 3);
        expect(changes.length, greaterThan(0));
        final before = changes.last;
        expect(before, contains('needle'));

        key.currentState!.resize(_narrow.toDouble());
        await tester.pump();

        final selectables = _selectablesUnder(
          viewKey.currentContext! as Element,
        );
        expect(selectables.length, greaterThan(0));
        final held = selectables
            .map((selectable) => selectable.getSelectedContent()?.plainText)
            .whereType<String>()
            .join();
        expect(held, before);
      }, size: const Size(80, 10));
    });
  });
}

const String _selectionDocument = '''
```dart
final x = 1;
final y = 2;
```

Select the needle here.
''';

/// Resizes a pane holding a markdown view, the way a pane splitter would.
class _ResizeHarness extends StatefulComponent {
  const _ResizeHarness({
    required this.viewKey,
    required this.onSelectionChanged,
    super.key,
  });

  final GlobalKey viewKey;
  final void Function(String) onSelectionChanged;

  @override
  State<_ResizeHarness> createState() => _ResizeHarnessState();
}

class _ResizeHarnessState extends State<_ResizeHarness> {
  double _width = _wide.toDouble();

  void resize(double value) => setState(() => _width = value);

  @override
  Component build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _width,
          child: SelectionArea(
            onSelectionChanged: component.onSelectionChanged,
            child: MarkdownView(
              _selectionDocument,
              key: component.viewKey,
              highlightTheme: _backedTheme,
            ),
          ),
        ),
        Expanded(child: const SizedBox()),
      ],
    );
  }
}

/// Every [Selectable] render object at or beneath [element], in tree order —
/// one per block under a markdown view.
List<Selectable> _selectablesUnder(Element element) {
  final found = <Selectable>[];
  void walk(Element element) {
    final renderObject = element is RenderObjectElement
        ? element.renderObject
        : null;
    if (renderObject is Selectable) found.add(renderObject! as Selectable);
    element.visitChildren(walk);
  }

  walk(element);
  return found;
}
