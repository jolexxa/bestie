import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

void main() {
  group('MarkdownBuilders', () {
    test('defaults() routes non-diff languages through highlightSpan', () {
      final builders = MarkdownBuilders.defaults();
      final span = builders.codeBlock!('final x = 1;', 'dart');
      expect(_flatten(span), 'final x = 1;');
    });

    test('defaults() routes lang == "diff" through diffSpan', () {
      const diff = '''
--- a/x
+++ b/x
@@ -1,1 +1,1 @@
-a
+b
''';
      final builders = MarkdownBuilders.defaults();
      final span = builders.codeBlock!(diff, 'diff');
      final text = _flatten(span);
      // diffSpan emits the file header + signed lines; highlightSpan would
      // emit the raw input. Header is the cheapest discriminator.
      expect(text, contains('── x'));
    });

    test('defaults() case-insensitive on lang', () {
      const diff = '''
--- a/x
+++ b/x
@@ -1,1 +1,1 @@
-a
+b
''';
      final builders = MarkdownBuilders.defaults();
      final span = builders.codeBlock!(diff, 'DIFF');
      expect(_flatten(span), contains('── x'));
    });

    test('defaults() with a null language falls through to highlightSpan', () {
      final builders = MarkdownBuilders.defaults();
      final span = builders.codeBlock!('arbitrary content', null);
      expect(_flatten(span), 'arbitrary content');
    });

    test('constructor accepts explicit hooks', () {
      InlineSpan myCodeBlock(String code, String? lang) =>
          TextSpan(text: 'BLOCK<$code:$lang>');
      InlineSpan myInline(String code) => TextSpan(text: 'INLINE<$code>');
      final builders = MarkdownBuilders(
        codeBlock: myCodeBlock,
        inlineCode: myInline,
      );
      expect(_flatten(builders.codeBlock!('foo', 'bar')), 'BLOCK<foo:bar>');
      expect(_flatten(builders.inlineCode!('baz')), 'INLINE<baz>');
    });

    test('defaults() leaves inlineCode null when theme has no background', () {
      final builders = MarkdownBuilders.defaults();
      expect(builders.inlineCode, isNull);
    });

    test('defaults() registers an inlineCode builder when bg is set', () {
      const bg = Color.fromRGB(30, 31, 41);
      const theme = HighlightTheme(styles: {}, background: bg);
      final builders = MarkdownBuilders.defaults(theme: theme);
      final span = builders.inlineCode!('foo') as TextSpan;
      expect(span.style?.backgroundColor, bg);
      expect(span.style?.fontWeight, FontWeight.bold);
      expect(span.text, 'foo');
    });

    test('defaults() inlineCode pins color to theme.fallback.color', () {
      // Without pinning, inline `code` would inherit the surrounding
      // paragraph's color (e.g. messageColor) instead of a code-appropriate
      // fg. This lock-in test guards against that regression.
      const bg = Color.fromRGB(30, 31, 41);
      const fg = Color.fromRGB(220, 220, 220);
      const theme = HighlightTheme(
        styles: {},
        fallback: TextStyle(color: fg),
        background: bg,
      );
      final builders = MarkdownBuilders.defaults(theme: theme);
      final span = builders.inlineCode!('foo') as TextSpan;
      expect(span.style?.color, fg);
      expect(span.style?.backgroundColor, bg);
    });
  });
}
