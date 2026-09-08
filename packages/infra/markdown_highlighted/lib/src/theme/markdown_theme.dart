import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

/// Style sheet for non-code markdown elements (headings, lists, quotes,
/// emphasis, links, etc.).
///
/// Defaults are attribute-only (bold / italic / underline / line-through) and
/// carry no foreground colors, so markdown content inherits the surrounding
/// [TextSpan] color through nocterm's `mergeStyle`. Callers that want a
/// richer palette should override the relevant fields.
@immutable
class MarkdownTheme {
  /// Creates a markdown theme. Any null field falls back to the surrounding
  /// span's style via [TextSpan]'s normal cascading.
  const MarkdownTheme({
    this.paragraphStyle,
    this.h1Style,
    this.h2Style,
    this.h3Style,
    this.h4Style,
    this.h5Style,
    this.h6Style,
    this.boldStyle,
    this.italicStyle,
    this.strikethroughStyle,
    this.inlineCodeStyle,
    this.codeBlockStyle,
    this.blockquoteStyle,
    this.linkStyle,
    this.listBullet = '• ',
    this.horizontalRule = '─',
  });

  /// Default terminal theme. Attribute-only — no fixed colors — so it blends
  /// into whatever foreground the host app is using. Mirrors the spirit of
  /// nocterm's `MarkdownStyleSheet.terminal()`.
  factory MarkdownTheme.terminal() {
    return const MarkdownTheme(
      // h1: bold; visitor also uppercases. Loudest heading.
      h1Style: TextStyle(fontWeight: FontWeight.bold),
      // h2: bold + underline. Strong section break.
      h2Style: TextStyle(
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
      ),
      // h3: bold. Clean subsection marker.
      h3Style: TextStyle(fontWeight: FontWeight.bold),
      // h4: bold italic — less heavy than h1-h3, still structural.
      h4Style: TextStyle(
        fontWeight: FontWeight.bold,
        fontStyle: FontStyle.italic,
      ),
      // h5: italic + underline — subtle structure marker.
      h5Style: TextStyle(
        fontStyle: FontStyle.italic,
        decoration: TextDecoration.underline,
      ),
      // h6: italic only — quietest leaf-level heading.
      h6Style: TextStyle(fontStyle: FontStyle.italic),
      boldStyle: TextStyle(fontWeight: FontWeight.bold),
      italicStyle: TextStyle(fontStyle: FontStyle.italic),
      strikethroughStyle: TextStyle(decoration: TextDecoration.lineThrough),
      inlineCodeStyle: TextStyle(fontWeight: FontWeight.bold),
      blockquoteStyle: TextStyle(fontStyle: FontStyle.italic),
      linkStyle: TextStyle(decoration: TextDecoration.underline),
    );
  }

  /// Base paragraph style. Other styles cascade on top of this.
  final TextStyle? paragraphStyle;

  /// Style applied to `# ` headings.
  final TextStyle? h1Style;

  /// Style applied to `## ` headings.
  final TextStyle? h2Style;

  /// Style applied to `### ` headings.
  final TextStyle? h3Style;

  /// Style applied to `#### ` headings.
  final TextStyle? h4Style;

  /// Style applied to `##### ` headings.
  final TextStyle? h5Style;

  /// Style applied to `###### ` headings.
  final TextStyle? h6Style;

  /// Style applied to `**bold**` / `__bold__`.
  final TextStyle? boldStyle;

  /// Style applied to `*italic*` / `_italic_`.
  final TextStyle? italicStyle;

  /// Style applied to `~~struck~~`.
  final TextStyle? strikethroughStyle;

  /// Style applied to inline `` `code` `` spans (fallback only — the
  /// `MarkdownBuilders.inlineCode` hook can override per-span entirely).
  final TextStyle? inlineCodeStyle;

  /// Style applied to fenced code blocks (fallback only — the
  /// `MarkdownBuilders.codeBlock` hook can override per-block entirely).
  final TextStyle? codeBlockStyle;

  /// Style applied to blockquote text. The `│` prefix uses the same style.
  final TextStyle? blockquoteStyle;

  /// Style applied to links. The trailing `[url]` annotation is shown in the
  /// same style but with decoration cleared.
  final TextStyle? linkStyle;

  /// Bullet glyph used for unordered list items.
  final String listBullet;

  /// Character used to draw horizontal rules (`---`, `***`, `___`). Repeated
  /// to fill the available width.
  final String horizontalRule;

  /// Returns a new theme where any field set in [other] overrides the
  /// corresponding field in this one. Unset fields in [other] keep this
  /// theme's value, so partial themes layer cleanly on top of defaults.
  MarkdownTheme merge(MarkdownTheme other) {
    return MarkdownTheme(
      paragraphStyle: other.paragraphStyle ?? paragraphStyle,
      h1Style: other.h1Style ?? h1Style,
      h2Style: other.h2Style ?? h2Style,
      h3Style: other.h3Style ?? h3Style,
      h4Style: other.h4Style ?? h4Style,
      h5Style: other.h5Style ?? h5Style,
      h6Style: other.h6Style ?? h6Style,
      boldStyle: other.boldStyle ?? boldStyle,
      italicStyle: other.italicStyle ?? italicStyle,
      strikethroughStyle: other.strikethroughStyle ?? strikethroughStyle,
      inlineCodeStyle: other.inlineCodeStyle ?? inlineCodeStyle,
      codeBlockStyle: other.codeBlockStyle ?? codeBlockStyle,
      blockquoteStyle: other.blockquoteStyle ?? blockquoteStyle,
      linkStyle: other.linkStyle ?? linkStyle,
      listBullet: other.listBullet,
      horizontalRule: other.horizontalRule,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownTheme &&
        other.paragraphStyle == paragraphStyle &&
        other.h1Style == h1Style &&
        other.h2Style == h2Style &&
        other.h3Style == h3Style &&
        other.h4Style == h4Style &&
        other.h5Style == h5Style &&
        other.h6Style == h6Style &&
        other.boldStyle == boldStyle &&
        other.italicStyle == italicStyle &&
        other.strikethroughStyle == strikethroughStyle &&
        other.inlineCodeStyle == inlineCodeStyle &&
        other.codeBlockStyle == codeBlockStyle &&
        other.blockquoteStyle == blockquoteStyle &&
        other.linkStyle == linkStyle &&
        other.listBullet == listBullet &&
        other.horizontalRule == horizontalRule;
  }

  @override
  int get hashCode => Object.hash(
    paragraphStyle,
    h1Style,
    h2Style,
    h3Style,
    h4Style,
    h5Style,
    h6Style,
    boldStyle,
    italicStyle,
    strikethroughStyle,
    inlineCodeStyle,
    codeBlockStyle,
    blockquoteStyle,
    linkStyle,
    listBullet,
    horizontalRule,
  );
}
