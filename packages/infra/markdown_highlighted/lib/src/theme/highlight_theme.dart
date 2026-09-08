import 'package:nocterm/nocterm.dart';

/// A mapping from scope names (e.g. `keyword`, `title.function`, `string`)
/// to terminal [TextStyle]s. Lookups walk dotted segments back toward
/// broader scopes — `title.function` falls back to `title`, which falls
/// back to [fallback].
class HighlightTheme {
  /// Creates a theme from a scope-to-style map.
  const HighlightTheme({
    required this.styles,
    this.fallback,
    this.background,
  });

  /// Map of scope name → terminal style. Keys may be either flat
  /// (`keyword`) or dotted (`title.function`).
  final Map<String, TextStyle> styles;

  /// Style applied to nodes whose scope is unknown (or `null`). When `null`,
  /// unknown nodes inherit the surrounding [TextSpan] style unchanged.
  final TextStyle? fallback;

  /// Optional backdrop color applied behind highlighted code (block + inline).
  /// When non-null, `highlightSpan` wraps its output in a span with this
  /// `backgroundColor` so the foreground colors read correctly against a
  /// consistent backdrop regardless of the terminal's own background.
  final Color? background;

  /// Resolves the style for a scope, walking dotted segments back toward
  /// broader categories until a match is found.
  TextStyle? styleFor(String? className) {
    if (className == null) return fallback;
    var key = className;
    while (true) {
      final style = styles[key];
      if (style != null) return style;
      final dot = key.lastIndexOf('.');
      if (dot < 0) return fallback;
      key = key.substring(0, dot);
    }
  }

  /// Dracula-inspired palette tuned for dark terminals.
  ///
  /// Foreground/background colors mirror the canonical Dracula scheme
  /// (https://draculatheme.com/). Styles are attribute-rich (colors + bold/
  /// italic) so they read well against a dark background; on a light terminal
  /// a host app should supply its own theme.
  static const HighlightTheme dracula = HighlightTheme(
    styles: _draculaStyles,
  );
}

const _pink = Color.fromRGB(255, 121, 198);
const _purple = Color.fromRGB(189, 147, 249);
const _cyan = Color.fromRGB(139, 233, 253);
const _green = Color.fromRGB(80, 250, 123);
const _yellow = Color.fromRGB(241, 250, 140);
const _orange = Color.fromRGB(255, 184, 108);
const _red = Color.fromRGB(255, 85, 85);
const _comment = Color.fromRGB(98, 114, 164);

const _italic = TextStyle(fontStyle: FontStyle.italic);
const _bold = TextStyle(fontWeight: FontWeight.bold);

const Map<String, TextStyle> _draculaStyles = {
  // Keywords & control
  'keyword': TextStyle(color: _pink, fontWeight: FontWeight.bold),
  'operator': TextStyle(color: _pink),
  'literal': TextStyle(color: _purple),
  'built_in': TextStyle(color: _cyan),
  'type': TextStyle(color: _cyan, fontStyle: FontStyle.italic),

  // Numbers & regex
  'number': TextStyle(color: _purple),
  'regexp': TextStyle(color: _red),

  // Strings
  'string': TextStyle(color: _yellow),
  'symbol': TextStyle(color: _yellow),
  'meta.string': TextStyle(color: _yellow),

  // Functions / titles / classes
  'title': TextStyle(color: _green),
  'title.function': TextStyle(color: _green),
  'title.class': TextStyle(color: _cyan, fontStyle: FontStyle.italic),
  'class': TextStyle(color: _cyan, fontStyle: FontStyle.italic),
  'function': TextStyle(color: _green),

  // Params & variables
  'params': TextStyle(color: _orange, fontStyle: FontStyle.italic),
  'variable': TextStyle(color: _orange),
  'variable.language': TextStyle(color: _pink, fontStyle: FontStyle.italic),
  'variable.constant': TextStyle(color: _purple),

  // Comments
  'comment': TextStyle(color: _comment, fontStyle: FontStyle.italic),
  'doctag': TextStyle(color: _comment, fontWeight: FontWeight.bold),
  'quote': TextStyle(color: _comment, fontStyle: FontStyle.italic),

  // Meta (preprocessor, attributes, decorators)
  'meta': TextStyle(color: _comment),
  'meta.keyword': TextStyle(color: _pink, fontWeight: FontWeight.bold),

  // Markup / template
  'section': TextStyle(color: _green, fontWeight: FontWeight.bold),
  'tag': TextStyle(color: _pink),
  'name': TextStyle(color: _pink),
  'attr': TextStyle(color: _green, fontStyle: FontStyle.italic),
  'attribute': TextStyle(color: _green),
  'bullet': TextStyle(color: _pink),
  'emphasis': _italic,
  'strong': _bold,
  'formula': TextStyle(color: _pink),
  'link': TextStyle(color: _cyan, decoration: TextDecoration.underline),

  // CSS-ish selectors
  'selector-tag': TextStyle(color: _pink),
  'selector-id': TextStyle(color: _green),
  'selector-class': TextStyle(color: _green),
  'selector-attr': TextStyle(color: _pink),
  'selector-pseudo': TextStyle(color: _green),

  // Templating
  'template-tag': TextStyle(color: _pink),
  'template-variable': TextStyle(color: _pink),

  // Diff (used when highlighting language: 'diff' inside SyntaxHighlight, not
  // by DiffView itself — DiffView paints +/- lines via its own colors)
  'addition': TextStyle(color: _green),
  'deletion': TextStyle(color: _red),
};
