import 'package:markdown_highlighted/src/internal/backdrop.dart';
import 'package:markdown_highlighted/src/internal/markdown_block.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/markdown_builders.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';
import 'package:markdown_highlighted/src/theme/highlight_theme.dart';
import 'package:markdown_highlighted/src/theme/markdown_theme.dart';
import 'package:markdown_highlighted/src/theme/math_theme.dart';
import 'package:markdown_highlighted/src/theme/math_theme_scope.dart';
import 'package:nocterm/nocterm.dart';

/// Renders a markdown document with syntax-highlighted code blocks and
/// optional diff rendering.
///
/// Parses [data] with GitHub-flavored markdown, walks the AST through a
/// [MarkdownVisitor], and lays the result out as a column of block
/// components — prose paragraphs, backdropped code blocks, rules, centred
/// math, tables. Each block is its own selectable with locally-indexed
/// selection, so a pane resize can reflow layout without shifting the
/// selectable text of any block: width never appears in a block's text.
///
/// Code blocks and inline code spans are routed through [builders] — pass
/// [MarkdownBuilders.defaults] (the default) to get syntax highlighting and
/// auto-routing of ` ```diff ` fences through `diffSpan`.
class MarkdownView extends StatefulComponent {
  /// Creates a markdown view.
  const MarkdownView(
    this.data, {
    super.key,
    this.theme,
    this.builders,
    this.highlightTheme = HighlightTheme.dracula,
    this.mathTheme,
    this.streaming = false,
  });

  /// The markdown source.
  final String data;

  /// Whether [data] is still growing.
  final bool streaming;

  /// Non-code element styling. When `null`, defaults to
  /// [MarkdownTheme.terminal].
  final MarkdownTheme? theme;

  /// Code block + inline code rendering hooks. When `null`, defaults to
  /// [MarkdownBuilders.defaults] (uses [highlightTheme]).
  final MarkdownBuilders? builders;

  /// Default highlight theme for the auto-supplied [MarkdownBuilders.defaults]
  /// when [builders] is null. Ignored when [builders] is non-null.
  final HighlightTheme highlightTheme;

  /// Styling for display math. When `null`, taken from the enclosing
  /// [MathThemeScope] — and [MathTheme.none] where there is none, which
  /// renders math exactly as it would without colorization.
  final MathTheme? mathTheme;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  late List<MarkdownBlock> _blocks;
  late MarkdownTheme _effectiveTheme;
  late MarkdownBuilders _effectiveBuilders;

  String? _lastData;
  MarkdownTheme? _lastTheme;
  MarkdownBuilders? _lastBuilders;
  HighlightTheme? _lastHighlightTheme;
  MathTheme? _lastMathTheme;
  int? _lastMaxWidth;
  bool? _lastStreaming;

  @override
  Component build(BuildContext context) {
    final mathTheme = component.mathTheme ?? MathThemeScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.toInt()
            : null;

        if (component.data != _lastData ||
            component.theme != _lastTheme ||
            component.builders != _lastBuilders ||
            component.highlightTheme != _lastHighlightTheme ||
            mathTheme != _lastMathTheme ||
            component.streaming != _lastStreaming ||
            maxWidth != _lastMaxWidth) {
          _lastData = component.data;
          _lastTheme = component.theme;
          _lastBuilders = component.builders;
          _lastHighlightTheme = component.highlightTheme;
          _lastMathTheme = mathTheme;
          _lastMaxWidth = maxWidth;
          _lastStreaming = component.streaming;

          final themeDefaults = MarkdownTheme.terminal();
          _effectiveTheme = component.theme == null
              ? themeDefaults
              : themeDefaults.merge(component.theme!);
          _effectiveBuilders =
              component.builders ??
              MarkdownBuilders.defaults(theme: component.highlightTheme);

          _blocks = _parse(maxWidth, mathTheme);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, block) in _blocks.indexed) ...[
              if (index > 0) const SizedBox(height: 1),
              _buildBlock(block),
            ],
          ],
        );
      },
    );
  }

  /// One row of text over the effective paragraph style — the cascade every
  /// block inherited from the document root when it was a single paragraph.
  Component _richText(InlineSpan span, {bool softWrap = true}) => RichText(
    text: TextSpan(style: _effectiveTheme.paragraphStyle, children: [span]),
    softWrap: softWrap,
  );

  Component _buildBlock(MarkdownBlock block) {
    switch (block) {
      case ProseBlock(:final span):
      case TableBlock(:final span):
        return _richText(span);
      case CodeBlock(:final span, :final background):
        return paintBackdrop(_richText(span), background);
      case RuleBlock():
        return const Divider(color: Colors.grey);
      case MathBlock(:final span):
        return Center(
          child: ClipRect(child: _richText(span, softWrap: false)),
        );
    }
  }

  List<MarkdownBlock> _parse(int? maxWidth, MathTheme mathTheme) {
    final nodes = buildMarkdownDocument().parse(component.data);
    final visitor = MarkdownVisitor(
      theme: _effectiveTheme,
      builders: _effectiveBuilders,
      mathTheme: mathTheme,
      maxWidth: maxWidth,
      codeBlockBackground: component.highlightTheme.background,
      streaming: component.streaming,
    );
    return visitor.visit(nodes);
  }
}
