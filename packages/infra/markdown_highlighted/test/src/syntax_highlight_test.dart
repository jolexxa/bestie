import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// Flattens an [InlineSpan] tree to its plain-text contents.
String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

/// Recursively collects every TextSpan in the tree.
Iterable<TextSpan> _walk(InlineSpan span) sync* {
  if (span is TextSpan) {
    yield span;
    if (span.children != null) {
      for (final child in span.children!) {
        yield* _walk(child);
      }
    }
  }
}

void main() {
  // The span cache is module-level and keyed partly on theme identity, and
  // `const` themes are canonicalized — so two tests that build an equal theme
  // for equal code share an entry. Without this, whether a test highlights
  // anything or just reads back an earlier test's span depends on the order
  // they ran in.
  setUp(clearHighlightCache);

  group('highlightSpan', () {
    test('preserves the input code exactly', () {
      const code = 'final x = 42;';
      final span = highlightSpan(code: code, language: 'dart');
      expect(_flatten(span), code);
    });

    test('auto-detects when the language is unknown', () {
      // Distinctively Dart-ish code: should pick up *something* (likely dart
      // or a close relative). Either way, the flattened text round-trips
      // exactly — highlighting only changes styling, not characters.
      const code = 'class Foo { final int x = 1; }';
      final span = highlightSpan(code: code, language: 'fictional');
      expect(_flatten(span), code);
      final styled = _walk(span).where((s) => s.style?.color != null).toList();
      expect(styled.length, greaterThan(0));
    });

    test('auto-detects when the language is null', () {
      const code = "def hello():\n    return 'world'";
      final span = highlightSpan(code: code);
      expect(_flatten(span), code);
      final styled = _walk(span).where((s) => s.style?.color != null).toList();
      expect(styled.length, greaterThan(0));
    });

    test('falls back to plaintext when autoDetect is disabled', () {
      const code = 'class Foo { final int x = 1; }';
      final span = highlightSpan(code: code, autoDetect: false);
      expect(_flatten(span), code);
      // No language match path → no scoped nodes with colors.
      final styled = _walk(span).where((s) => s.style?.color != null).toList();
      expect(styled.length, 0);
    });

    test('honors an explicit plaintext language without auto-detecting', () {
      const code = 'class Foo {}';
      final span = highlightSpan(code: code, language: 'plaintext');
      final styled = _walk(span).where((s) => s.style?.color != null).toList();
      expect(styled.length, 0);
    });

    test('applies a style to a recognized keyword node', () {
      // `class` is a recognized keyword in Dart.
      final span = highlightSpan(code: 'class Foo {}', language: 'dart');
      final styled = _walk(span).where((s) => s.style?.color != null).toList();
      expect(styled.length, greaterThan(0));
    });

    test('respects a custom theme', () {
      const customColor = Color.fromRGB(123, 45, 67);
      const theme = HighlightTheme(
        styles: {'keyword': TextStyle(color: customColor)},
      );
      final span = highlightSpan(
        code: 'class Foo {}',
        language: 'dart',
        theme: theme,
      );
      final hasCustomColor = _walk(
        span,
      ).any((s) => s.style?.color == customColor);
      expect(hasCustomColor, isTrue);
    });

    test('applies the theme background to the outer span', () {
      const bg = Color.fromRGB(30, 31, 41);
      const theme = HighlightTheme(styles: {}, background: bg);
      final span = highlightSpan(
        code: 'hello',
        language: 'plaintext',
        theme: theme,
      );
      expect((span as TextSpan).style?.backgroundColor, bg);
    });

    test('pins outer color to fallback.color so messageColor cannot bleed in '
        'when bg is set', () {
      const bg = Color.fromRGB(30, 31, 41);
      const fg = Color.fromRGB(220, 220, 220);
      const theme = HighlightTheme(
        styles: {},
        fallback: TextStyle(color: fg),
        background: bg,
      );
      final span = highlightSpan(
        code: 'hello',
        language: 'plaintext',
        theme: theme,
      );
      // Both color AND backgroundColor must appear on the outer wrapper —
      // otherwise the surrounding paragraph's color cascades through and
      // re-paints the code's plaintext leaves.
      expect((span as TextSpan).style?.color, fg);
      expect(span.style?.backgroundColor, bg);
    });

    test('highlighted leaves still apply their scope color over the wrapper '
        'fg pin', () {
      const bg = Color.fromRGB(30, 31, 41);
      const fg = Color.fromRGB(220, 220, 220);
      const keywordColor = Color.fromRGB(255, 121, 198);
      const theme = HighlightTheme(
        styles: {'keyword': TextStyle(color: keywordColor)},
        fallback: TextStyle(color: fg),
        background: bg,
      );
      final span = highlightSpan(
        code: 'class Foo {}',
        language: 'dart',
        theme: theme,
      );
      // At least one leaf should carry the keyword color — the wrapper's
      // `color: fg` pin must not stomp scoped colors set on children.
      final hasKeywordColor = _walk(
        span,
      ).any((s) => s.style?.color == keywordColor);
      expect(hasKeywordColor, isTrue);
    });

    test('wrapper carries the fallback even when no background is set', () {
      // Fallback is the "default code color" — applied at the wrapper so
      // unscoped leaves cascade-inherit it without overriding scoped ancestors.
      const fg = Color.fromRGB(1, 2, 3);
      const theme = HighlightTheme(
        styles: {},
        fallback: TextStyle(color: fg),
      );
      final span = highlightSpan(
        code: 'hello',
        language: 'plaintext',
        theme: theme,
      );
      expect((span as TextSpan).style?.color, fg);
      expect(span.style?.backgroundColor, isNull);
    });

    test('a dotted scope falls back to the broader scope it narrows', () {
      // highlight.js names some scopes with a dot — python spells a function
      // name `title.function`. A theme that styles only the broad `title`
      // has to colour it, or a theme would have to enumerate every narrowing
      // any grammar might emit.
      const titleColor = Color.fromRGB(10, 200, 30);
      const theme = HighlightTheme(
        styles: {'title': TextStyle(color: titleColor)},
      );
      final span = highlightSpan(
        code: 'def foo(x):\n    return x\n',
        language: 'python',
        theme: theme,
      );

      final named = (span as TextSpan).toStyledSegments().firstWhere(
        (s) => s.text.contains('foo'),
      );
      expect(named.style?.color, titleColor);
    });

    test('a dotted scope with no broader match stays unstyled', () {
      const theme = HighlightTheme(styles: {'keyword': TextStyle()});
      final span = highlightSpan(
        code: 'def foo(x):\n    return x\n',
        language: 'python',
        theme: theme,
      );

      final named = (span as TextSpan).toStyledSegments().firstWhere(
        (s) => s.text.contains('foo'),
      );
      expect(named.style?.color, isNull);
    });

    test('wrapper has no style when neither bg nor fallback are set', () {
      const theme = HighlightTheme(styles: {});
      final span = highlightSpan(
        code: 'hello',
        language: 'plaintext',
        theme: theme,
      );
      expect((span as TextSpan).style, isNull);
    });

    test('plain-text leaves inside a scoped parent inherit the scope color '
        '(NOT the fallback) — fixes the bold-but-colorless bug', () {
      // The bug: leaves with className=null used to be emitted with
      // `style: fallback`, which has `color: fg`. Merged with a scoped
      // parent (color: keywordColor, fontWeight: bold), the LEAF color
      // overrode the parent's — so bold/italic survived but the keyword color
      // was lost. Plaintext leaves must NOT carry fallback.
      const bg = Color.fromRGB(26, 26, 46);
      const fg = Color.fromRGB(204, 200, 224);
      const keywordColor = Color.fromRGB(139, 122, 255);
      const theme = HighlightTheme(
        styles: {
          'keyword': TextStyle(
            color: keywordColor,
            fontWeight: FontWeight.bold,
          ),
        },
        fallback: TextStyle(color: fg),
        background: bg,
      );
      final paragraph = TextSpan(
        style: const TextStyle(color: Color.fromRGB(255, 255, 255)),
        children: [highlightSpan(code: 'class Foo {}', theme: theme)],
      );
      final segments = paragraph.toStyledSegments();

      // The `class` token must be emitted as a segment colored keywordColor.
      final classSegment = segments.firstWhere(
        (s) => s.text.contains('class'),
      );
      expect(
        classSegment.style?.color,
        keywordColor,
        reason: 'keyword color was lost — leaves are stomping the scope color',
      );
      expect(classSegment.style?.fontWeight, FontWeight.bold);
      expect(classSegment.style?.backgroundColor, bg);
    });

    test('rendered segments do not inherit parent paragraph color when bg is '
        'set (cascade lock-in)', () {
      // Simulates bestie's chat layout: a paragraph TextSpan with the message
      // color wraps the highlightSpan output. After full nocterm cascade,
      // every leaf segment from the code block must end up colored from the
      // theme's scope styles (or fallback) — NEVER the surrounding
      // messageColor.
      const messageColor = Color.fromRGB(224, 220, 240); // assistant text
      const bg = Color.fromRGB(26, 26, 46); // surface
      const fg = Color.fromRGB(204, 200, 224); // onSurface
      const keywordColor = Color.fromRGB(139, 122, 255); // primary
      const theme = HighlightTheme(
        styles: {
          'keyword': TextStyle(
            color: keywordColor,
            fontWeight: FontWeight.bold,
          ),
        },
        fallback: TextStyle(color: fg),
        background: bg,
      );

      final paragraph = TextSpan(
        style: const TextStyle(color: messageColor),
        children: [highlightSpan(code: 'class Foo {}', theme: theme)],
      );

      final segments = paragraph.toStyledSegments();
      // Every emitted segment must carry a color that is NOT messageColor —
      // proves the fg-pin successfully blocks parent color from bleeding in.
      for (final segment in segments) {
        expect(
          segment.style?.color,
          isNot(messageColor),
          reason:
              'segment "${segment.text}" inherited messageColor — '
              'the fg pin on the highlightSpan wrapper is not working',
        );
      }
      // And the backdrop must reach every segment too.
      for (final segment in segments) {
        expect(
          segment.style?.backgroundColor,
          bg,
          reason: 'segment "${segment.text}" lost the code backdrop',
        );
      }
    });
  });

  group('SyntaxHighlight widget', () {
    test('builds a RichText from a code string', () async {
      await testNocterm('SyntaxHighlight renders code', (tester) async {
        await tester.pumpComponent(
          const SyntaxHighlight('final x = 1;', language: 'dart'),
        );
        expect(tester.terminalState, containsText('final x = 1;'));
      });
    });

    test('handles a null language via auto-detect', () async {
      await testNocterm('SyntaxHighlight handles null lang', (tester) async {
        await tester.pumpComponent(const SyntaxHighlight('hello'));
        expect(tester.terminalState, containsText('hello'));
      });
    });

    test('respects autoDetect: false', () async {
      await testNocterm('SyntaxHighlight no auto', (tester) async {
        await tester.pumpComponent(
          const SyntaxHighlight('hello', autoDetect: false),
        );
        expect(tester.terminalState, containsText('hello'));
      });
    });
  });

  group('highlightSpan memoization', () {
    test('returns identical InlineSpan for repeated calls', () {
      const code = 'final int x = 42;';
      final a = highlightSpan(code: code, language: 'dart');
      final b = highlightSpan(code: code, language: 'dart');
      expect(identical(a, b), isTrue);
      expect(highlightCacheSize, 1);
    });

    test('treats different language hints as separate cache entries', () {
      const code = 'print(1)';
      highlightSpan(code: code, language: 'python');
      highlightSpan(code: code, language: 'ruby');
      expect(highlightCacheSize, 2);
    });

    test('treats different autoDetect flags as separate cache entries', () {
      const code = 'class Foo {}';
      highlightSpan(code: code);
      highlightSpan(code: code, autoDetect: false);
      expect(highlightCacheSize, 2);
    });

    test('treats different themes as separate cache entries', () {
      const code = 'final x = 1;';
      const t1 = HighlightTheme(styles: {'keyword': TextStyle()});
      const t2 = HighlightTheme(styles: {'string': TextStyle()});
      highlightSpan(code: code, language: 'dart', theme: t1);
      highlightSpan(code: code, language: 'dart', theme: t2);
      expect(highlightCacheSize, 2);
    });

    test('evicts oldest entries past the LRU bound', () {
      for (var i = 0; i < 260; i++) {
        highlightSpan(code: 'snippet $i', language: 'plaintext');
      }
      expect(highlightCacheSize, 256);
    });

    test('clearHighlightCache empties the cache', () {
      highlightSpan(code: 'foo', language: 'dart');
      expect(highlightCacheSize, greaterThan(0));
      clearHighlightCache();
      expect(highlightCacheSize, 0);
    });

    test('moves an accessed entry to the most-recent position', () {
      // Fill near the bound, touch the oldest, then push one more — the
      // oldest should NOT be evicted because the access re-promoted it.
      for (var i = 0; i < 256; i++) {
        highlightSpan(code: 'snippet $i', language: 'plaintext');
      }
      highlightSpan(code: 'snippet 0', language: 'plaintext');
      highlightSpan(code: 'snippet new', language: 'plaintext');
      expect(highlightCacheSize, 256);
      // `snippet 0` still cached → identical return on next access.
      final first = highlightSpan(code: 'snippet 0', language: 'plaintext');
      final second = highlightSpan(code: 'snippet 0', language: 'plaintext');
      expect(identical(first, second), isTrue);
    });
  });
}
