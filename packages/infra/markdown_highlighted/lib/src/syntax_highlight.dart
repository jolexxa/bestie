import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/all.dart';
import 'package:markdown_highlighted/src/languages.dart';
import 'package:markdown_highlighted/src/theme/highlight_theme.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

/// Renders a block of source code with syntax highlighting.
///
/// Composes through [highlightSpan]. When [language] is null or unknown and
/// [autoDetect] is true (default), runs a cross-language relevance scan and
/// picks the best match; set false to skip the scan and fall back to
/// plaintext (useful in hot per-line loops).
class SyntaxHighlight extends StatelessComponent {
  /// Creates a syntax-highlighted code block.
  const SyntaxHighlight(
    this.code, {
    super.key,
    this.language,
    this.theme = HighlightTheme.dracula,
    this.autoDetect = true,
  });

  /// The source code to render.
  final String code;

  /// Language id (e.g. `dart`, `rust`, `bash`). Null/unknown triggers
  /// auto-detection when [autoDetect] is true, else falls back to plaintext.
  final String? language;

  /// Scope → style map. Defaults to [HighlightTheme.dracula].
  final HighlightTheme theme;

  /// When true (default), unknown/null languages run a cross-language
  /// relevance scan. When false, they fall straight to plaintext.
  final bool autoDetect;

  @override
  Component build(BuildContext context) {
    return RichText(
      text: highlightSpan(
        code: code,
        language: language,
        theme: theme,
        autoDetect: autoDetect,
      ),
    );
  }
}

/// Highlights [code] and returns the resulting [InlineSpan] directly, for
/// embedding in a larger [TextSpan] tree (diff lines, markdown code blocks).
///
/// With ~500 languages registered, the auto-detect scan is not free — pass
/// `autoDetect: false` on hot per-line paths.
///
/// Results are memoized in an LRU keyed by `(code, language, autoDetect,
/// theme)`. [theme] is matched by identity, so reusing a single instance
/// (e.g. [HighlightTheme.dracula] or one constructed once at app start) keeps
/// hit rates high.
InlineSpan highlightSpan({
  required String code,
  String? language,
  HighlightTheme theme = HighlightTheme.dracula,
  bool autoDetect = true,
}) {
  final key = _CacheKey(
    code: code,
    language: language,
    autoDetect: autoDetect,
    theme: theme,
  );
  final cached = _cache.get(key);
  if (cached != null) return cached;

  registerAllLanguages();
  final normalized = language?.toLowerCase();
  final Result result;
  if (normalized != null && isLanguageSupported(normalized)) {
    result = highlight.parse(code, languageId: normalized);
  } else if (autoDetect) {
    // Only entry point for the cross-language relevance scan; @internal.
    // ignore: invalid_use_of_internal_member
    result = highlight.highlightAuto(code, builtinLanguages.keys.toList());
  } else {
    result = highlight.parse(code, languageId: 'plaintext');
  }
  final span = TextSpan(
    style: _wrapperStyle(theme),
    children: _spansForNodes(result.nodes ?? const [], theme),
  );
  _cache.put(key, span);
  return span;
}

/// Computes the outer wrapper style for a highlighted span. Carries the
/// theme's [HighlightTheme.fallback] (so unscoped leaves inherit the
/// fallback color via cascade) and overlays the [HighlightTheme.background]
/// when present. Returns `null` when neither is set so callers' own parent
/// styles cascade through unchanged.
TextStyle? _wrapperStyle(HighlightTheme theme) {
  final fb = theme.fallback;
  final bg = theme.background;
  if (fb == null && bg == null) return null;
  if (fb == null) return TextStyle(backgroundColor: bg);
  if (bg == null) return fb;
  return fb.copyWith(backgroundColor: bg);
}

/// Clears the [highlightSpan] memoization cache.
@visibleForTesting
void clearHighlightCache() => _cache.clear();

/// Current entry count in the [highlightSpan] memoization cache.
@visibleForTesting
int get highlightCacheSize => _cache.length;

final _cache = _LruCache<_CacheKey, InlineSpan>(maxEntries: 256);

@immutable
class _CacheKey {
  const _CacheKey({
    required this.code,
    required this.language,
    required this.autoDetect,
    required this.theme,
  });

  final String code;
  final String? language;
  final bool autoDetect;
  final HighlightTheme theme;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      other.code == code &&
      other.language == language &&
      other.autoDetect == autoDetect &&
      identical(other.theme, theme);

  @override
  int get hashCode =>
      Object.hash(code, language, autoDetect, identityHashCode(theme));
}

class _LruCache<K, V> {
  _LruCache({required this.maxEntries});

  final int maxEntries;
  final _entries = <K, V>{};

  int get length => _entries.length;

  V? get(K key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    _entries
      ..remove(key)
      ..[key] = value;
    if (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}

/// Walks a list of [Node]s into the equivalent [InlineSpan] tree.
List<InlineSpan> _spansForNodes(List<Node> nodes, HighlightTheme theme) {
  final spans = <InlineSpan>[];
  for (final node in nodes) {
    spans.add(_spanForNode(node, theme));
  }
  return spans;
}

InlineSpan _spanForNode(Node node, HighlightTheme theme) {
  // Scope-only lookup: do NOT fall through to `theme.fallback` here. Plain
  // text leaves nested inside a scoped parent must have `style: null` so they
  // inherit the parent scope's color via cascade. If we applied the fallback
  // at the leaf level, its `color` would override the parent scope and every
  // token would render in the fallback color instead of its scope color.
  // The fallback is applied once at the outer wrapper via [_wrapperStyle].
  final style = _scopeStyle(theme, node.className);
  if (node.value != null) {
    return TextSpan(text: node.value, style: style);
  }
  return TextSpan(
    style: style,
    children: _spansForNodes(node.children, theme),
  );
}

/// Looks up the style for [className] in `theme.styles`, walking dotted
/// segments back toward broader scopes. Returns `null` when nothing matches —
/// unlike [HighlightTheme.styleFor], does NOT fall through to `theme.fallback`.
TextStyle? _scopeStyle(HighlightTheme theme, String? className) {
  if (className == null) return null;
  var key = className;
  while (true) {
    final style = theme.styles[key];
    if (style != null) return style;
    final dot = key.lastIndexOf('.');
    if (dot < 0) return null;
    key = key.substring(0, dot);
  }
}
