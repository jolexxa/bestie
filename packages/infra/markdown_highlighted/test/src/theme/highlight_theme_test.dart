import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('HighlightTheme.styleFor', () {
    const fallback = TextStyle(color: Color.fromRGB(1, 2, 3));
    const keyword = TextStyle(color: Color.fromRGB(255, 0, 0));
    const titleFn = TextStyle(color: Color.fromRGB(0, 255, 0));

    const theme = HighlightTheme(
      styles: {
        'keyword': keyword,
        'title.function': titleFn,
      },
      fallback: fallback,
    );

    test('returns the fallback for null className', () {
      expect(theme.styleFor(null), fallback);
    });

    test('returns the style for an exact match', () {
      expect(theme.styleFor('keyword'), keyword);
    });

    test('returns the most-specific dotted match', () {
      expect(theme.styleFor('title.function'), titleFn);
    });

    test('walks dots back toward broader scopes', () {
      const styles = {'title': titleFn};
      const t = HighlightTheme(styles: styles);
      expect(t.styleFor('title.function'), titleFn);
    });

    test('returns the fallback when nothing matches', () {
      expect(theme.styleFor('not-a-scope'), fallback);
    });

    test('returns null when there is no fallback and no match', () {
      const t = HighlightTheme(styles: {});
      expect(t.styleFor('whatever'), isNull);
    });
  });

  group('HighlightTheme.dracula', () {
    test('has a keyword style', () {
      expect(HighlightTheme.dracula.styleFor('keyword'), isNotNull);
    });

    test('falls back through dotted scopes', () {
      // `meta.string` is defined explicitly; `meta.foo` should fall back to
      // `meta`.
      expect(HighlightTheme.dracula.styleFor('meta.foo'), isNotNull);
    });
  });
}
