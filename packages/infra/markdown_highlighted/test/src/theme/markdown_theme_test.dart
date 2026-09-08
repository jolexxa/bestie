import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownTheme.terminal', () {
    test('provides bold/italic/decoration attributes without colors', () {
      final theme = MarkdownTheme.terminal();
      expect(theme.boldStyle?.fontWeight, FontWeight.bold);
      expect(theme.italicStyle?.fontStyle, FontStyle.italic);
      expect(
        theme.strikethroughStyle?.decoration,
        TextDecoration.lineThrough,
      );
      expect(theme.linkStyle?.decoration, TextDecoration.underline);
      // No colors, by design.
      expect(theme.boldStyle?.color, isNull);
    });
  });

  group('MarkdownTheme.merge', () {
    test('overrides only set fields on the other theme', () {
      final base = MarkdownTheme.terminal();
      const override = MarkdownTheme(
        boldStyle: TextStyle(color: Color.fromRGB(255, 0, 0)),
      );
      final merged = base.merge(override);
      expect(merged.boldStyle?.color, const Color.fromRGB(255, 0, 0));
      // Fields not in override should fall back to base.
      expect(merged.italicStyle?.fontStyle, FontStyle.italic);
    });

    test('preserves listBullet and horizontalRule from the override', () {
      final base = MarkdownTheme.terminal();
      const override = MarkdownTheme(
        listBullet: '> ',
        horizontalRule: '=',
      );
      final merged = base.merge(override);
      expect(merged.listBullet, '> ');
      expect(merged.horizontalRule, '=');
    });
  });

  group('MarkdownTheme equality', () {
    // Callers build a theme inline on every rebuild, so a renderer that caches
    // its parse against the previous theme only ever hits that cache if two
    // separately-constructed themes with the same styling compare equal.
    test('two separately built themes with the same styling match', () {
      const red = TextStyle(color: Color.fromRGB(255, 0, 0));
      const a = MarkdownTheme(paragraphStyle: red, boldStyle: red);
      const b = MarkdownTheme(paragraphStyle: red, boldStyle: red);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a difference in any single field separates two themes', () {
      const base = MarkdownTheme();
      const bold = TextStyle(fontWeight: FontWeight.bold);
      final variants = <MarkdownTheme>[
        const MarkdownTheme(paragraphStyle: bold),
        const MarkdownTheme(h1Style: bold),
        const MarkdownTheme(h2Style: bold),
        const MarkdownTheme(h3Style: bold),
        const MarkdownTheme(h4Style: bold),
        const MarkdownTheme(h5Style: bold),
        const MarkdownTheme(h6Style: bold),
        const MarkdownTheme(boldStyle: bold),
        const MarkdownTheme(italicStyle: bold),
        const MarkdownTheme(strikethroughStyle: bold),
        const MarkdownTheme(inlineCodeStyle: bold),
        const MarkdownTheme(codeBlockStyle: bold),
        const MarkdownTheme(blockquoteStyle: bold),
        const MarkdownTheme(linkStyle: bold),
        const MarkdownTheme(listBullet: '> '),
        const MarkdownTheme(horizontalRule: '='),
      ];

      for (final variant in variants) {
        expect(variant, isNot(base));
      }
      expect(variants.toSet(), hasLength(variants.length));
    });

    test('a theme is not equal to some other object', () {
      expect(const MarkdownTheme(), isNot('not a theme'));
    });
  });
}
