import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/internal/math_syntax.dart';

/// Builds the `md.Document` used everywhere markdown is parsed — the app view
/// and every test — so math recognition is configured in exactly one place.
///
/// Registers the inline math delimiters ([mathInlineSyntaxes]) for
/// mid-paragraph and table-cell contexts and the block-level display-math
/// syntaxes ([mathBlockSyntaxes]) so a standalone `\[…\]` / `$$…$$` block is
/// captured raw and survives blank lines and leading-`-` continuations.
md.Document buildMarkdownDocument() {
  return md.Document(
    extensionSet: md.ExtensionSet.gitHubFlavored,
    inlineSyntaxes: mathInlineSyntaxes,
    blockSyntaxes: mathBlockSyntaxes,
    encodeHtml: false,
  );
}
