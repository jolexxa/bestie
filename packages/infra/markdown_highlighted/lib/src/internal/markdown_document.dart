import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/internal/block_boundary_probe.dart';
import 'package:markdown_highlighted/src/internal/math_syntax.dart';
import 'package:markdown_highlighted/src/internal/orphan_indent_syntax.dart';

/// The block syntaxes every markdown parse uses, in the order they are tried.
///
/// Display math comes first so a `\[…\]` or `$$…$$` block is captured raw
/// before any other syntax can claim its lines. Then the GitHub-flavored
/// extensions, then the CommonMark syntaxes, with [OrphanIndentSyntax] in
/// place of the indented code block.
final List<md.BlockSyntax> markdownBlockSyntaxes = List.unmodifiable([
  ...mathBlockSyntaxes,
  ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  const md.EmptyBlockSyntax(),
  const md.HtmlBlockSyntax(),
  const md.SetextHeaderSyntax(),
  const md.HeaderSyntax(),
  const OrphanIndentSyntax(),
  const md.BlockquoteSyntax(),
  const md.HorizontalRuleSyntax(),
  const md.UnorderedListSyntax(),
  const md.OrderedListSyntax(),
  const md.LinkReferenceDefinitionSyntax(),
  const md.ParagraphSyntax(),
]);

/// Builds the `md.Document` used everywhere markdown is parsed — the app view
/// and every test — so the grammar is configured in exactly one place.
///
/// Registers the inline math delimiters ([mathInlineSyntaxes]) for
/// mid-paragraph and table-cell contexts ahead of the GitHub-flavored inline
/// syntaxes, and [markdownBlockSyntaxes] as the only block syntaxes. A
/// [probe] goes ahead of them all, where it sees every block start.
md.Document buildMarkdownDocument({BlockBoundaryProbe? probe}) {
  return md.Document(
    extensionSet: md.ExtensionSet(
      const [],
      md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
    ),
    inlineSyntaxes: mathInlineSyntaxes,
    blockSyntaxes: [?probe, ...markdownBlockSyntaxes],
    withDefaultBlockSyntaxes: false,
    encodeHtml: false,
  );
}
