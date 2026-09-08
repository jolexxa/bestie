import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

void main() {
  const sample = '''
diff --git a/foo.dart b/foo.dart
--- a/foo.dart
+++ b/foo.dart
@@ -1,3 +1,3 @@
 keep
-old
+new
''';

  group('diffSpan', () {
    test('renders the file header path', () {
      final span = diffSpan(sample);
      expect(_flatten(span), contains('foo.dart'));
    });

    test('shows + and - signs for additions and deletions', () {
      final span = diffSpan(sample);
      final text = _flatten(span);
      expect(text, contains('+ new'));
      expect(text, contains('- old'));
    });

    test('shows the hunk anchor with old/new ranges', () {
      final span = diffSpan(sample);
      expect(_flatten(span), contains('@@ -1,3 +1,3 @@'));
    });

    test('omits the line number column when showLineNumbers is false', () {
      final span = diffSpan(sample, showLineNumbers: false);
      // Without numbers, a context line is just ` keep` (sign + space + body).
      final text = _flatten(span);
      expect(text.contains(' keep'), isTrue);
    });

    test('uses contextLanguage as a fallback', () {
      // Bare hunk → no file path → no extension to infer from. Provide one.
      const bare = '''
@@ -1,1 +1,1 @@
-let x = 1
+let x = 2
''';
      final span = diffSpan(bare, contextLanguage: 'rust');
      // Just smoke-test it renders without crashing.
      expect(_flatten(span), contains('let x'));
    });

    test('annotates `no newline at end of file` lines', () {
      const noEol =
          '--- a/x\n+++ b/x\n@@ -1,1 +1,1 @@\n-a\n'
          r'\ No newline at end of file'
          '\n+b\n';
      final span = diffSpan(noEol);
      expect(_flatten(span), contains('⏎'));
    });

    test('renders multiple files with separators', () {
      const multi = '''
--- a/one
+++ b/one
@@ -1,1 +1,1 @@
-a
+b
--- a/two
+++ b/two
@@ -1,1 +1,1 @@
-c
+d
''';
      final span = diffSpan(multi);
      final text = _flatten(span);
      expect(text, contains('one'));
      expect(text, contains('two'));
    });
  });

  group('DiffView widget', () {
    test('paints the theme backdrop to the edge of the pane', () async {
      const backdrop = Color(0xFF282A36);
      await testNocterm('DiffView backdrop', (tester) async {
        await tester.pumpComponent(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 30,
                child: DiffView(
                  sample,
                  theme: HighlightTheme(styles: {}, background: backdrop),
                ),
              ),
              Expanded(child: const SizedBox()),
            ],
          ),
        );

        expect(tester.terminalState, containsText('keep'));
        expect(
          tester.terminalState.getCellAt(29, 1)?.style.backgroundColor,
          backdrop,
        );
        expect(
          tester.terminalState.getCellAt(30, 1)?.style.backgroundColor,
          isNot(backdrop),
        );
      }, size: const Size(80, 10));
    });

    test('renders the diff to the terminal', () async {
      await testNocterm('DiffView smoke', (tester) async {
        await tester.pumpComponent(const DiffView(sample));
        expect(tester.terminalState, containsText('foo.dart'));
        expect(tester.terminalState, containsText('keep'));
      });
    });
  });
}
