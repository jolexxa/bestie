import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';

/// Returns a [HighlightTheme] derived from [appTheme]'s semantic palette.
/// Results are memoized by [AppThemeData] identity, so the same theme
/// instance reused across builds returns the same [HighlightTheme] instance —
/// keeping `highlightSpan`'s LRU cache effective.
HighlightTheme syntaxThemeFor(AppThemeData appTheme) {
  final cached = _cache[appTheme];
  if (cached != null) return cached;
  final derived = _derive(appTheme);
  _cache[appTheme] = derived;
  return derived;
}

final _cache = Expando<HighlightTheme>('appThemeSyntaxTheme');

HighlightTheme _derive(AppThemeData t) {
  return HighlightTheme(
    background: t.surface,
    fallback: TextStyle(color: t.onSurface),
    styles: {
      // Keywords & control flow
      'keyword': TextStyle(color: t.primary, fontWeight: FontWeight.bold),
      'operator': TextStyle(color: t.onSurface),
      'literal': TextStyle(color: t.accent),
      'built_in': TextStyle(color: t.info),
      'type': TextStyle(color: t.info, fontStyle: FontStyle.italic),

      // Numbers / regex
      'number': TextStyle(color: t.warning),
      'regexp': TextStyle(color: t.error),

      // Strings
      'string': TextStyle(color: t.success),
      'symbol': TextStyle(color: t.success),
      'meta.string': TextStyle(color: t.success),

      // Functions / classes / titles
      'title': TextStyle(color: t.secondary),
      'title.function': TextStyle(color: t.secondary),
      'title.class': TextStyle(color: t.info, fontStyle: FontStyle.italic),
      'class': TextStyle(color: t.info, fontStyle: FontStyle.italic),
      'function': TextStyle(color: t.secondary),

      // Params & variables
      'params': TextStyle(color: t.warning, fontStyle: FontStyle.italic),
      'variable': TextStyle(color: t.onSurface),
      'variable.language': TextStyle(
        color: t.primary,
        fontStyle: FontStyle.italic,
      ),
      'variable.constant': TextStyle(color: t.accent),

      // Comments — use mutedAccent for contrast on light themes where `muted`
      // sits too close to `surface`.
      'comment': TextStyle(
        color: t.mutedAccent,
        fontStyle: FontStyle.italic,
      ),
      'doctag': TextStyle(color: t.mutedAccent, fontWeight: FontWeight.bold),
      'quote': TextStyle(color: t.mutedAccent, fontStyle: FontStyle.italic),

      // Meta (preprocessor / decorators / annotations)
      'meta': TextStyle(color: t.mutedAccent),
      'meta.keyword': TextStyle(color: t.primary, fontWeight: FontWeight.bold),

      // Markup / template
      'section': TextStyle(color: t.secondary, fontWeight: FontWeight.bold),
      'tag': TextStyle(color: t.primary),
      'name': TextStyle(color: t.primary),
      'attr': TextStyle(color: t.success, fontStyle: FontStyle.italic),
      'attribute': TextStyle(color: t.success),
      'bullet': TextStyle(color: t.primary),
      'emphasis': const TextStyle(fontStyle: FontStyle.italic),
      'strong': const TextStyle(fontWeight: FontWeight.bold),
      'formula': TextStyle(color: t.primary),
      'link': TextStyle(
        color: t.info,
        decoration: TextDecoration.underline,
      ),

      // CSS-ish selectors
      'selector-tag': TextStyle(color: t.primary),
      'selector-id': TextStyle(color: t.success),
      'selector-class': TextStyle(color: t.success),
      'selector-attr': TextStyle(color: t.primary),
      'selector-pseudo': TextStyle(color: t.success),

      // Templating
      'template-tag': TextStyle(color: t.primary),
      'template-variable': TextStyle(color: t.primary),

      // Diff scopes (when highlight.js detects a diff language; DiffView paints
      // its own colors).
      'addition': TextStyle(color: t.success),
      'deletion': TextStyle(color: t.error),
    },
  );
}
