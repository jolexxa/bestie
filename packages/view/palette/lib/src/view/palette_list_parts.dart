import 'package:bestie_ui/bestie_ui.dart';
import 'package:characters/characters.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The theme colour and weight for text in [tone].
TextStyle paneToneStyle(AppThemeData theme, PaneTone tone) => switch (tone) {
  PaneTone.plain => TextStyle(color: theme.onSurface),
  PaneTone.primary => TextStyle(color: theme.primary),
  PaneTone.secondary => TextStyle(color: theme.secondary),
  PaneTone.info => TextStyle(color: theme.info),
  PaneTone.muted => TextStyle(color: theme.muted),
  PaneTone.subtle => TextStyle(color: theme.outline),
  PaneTone.success => TextStyle(color: theme.success),
  PaneTone.warning => TextStyle(color: theme.warning),
  PaneTone.danger => TextStyle(color: theme.error),
  PaneTone.loading => TextStyle(color: theme.loading),
  PaneTone.emphasis => TextStyle(
    color: theme.onBackground,
    fontWeight: FontWeight.bold,
  ),
  PaneTone.highlight => TextStyle(color: theme.highVisibility),
};

/// [spans] as styled text.
TextSpan paneSpans(AppThemeData theme, List<PaneSpan> spans) => TextSpan(
  children: [
    for (final span in spans)
      TextSpan(text: span.text, style: paneToneStyle(theme, span.tone)),
  ],
);

/// Cells [spans] take up on screen.
int paneSpansWidth(List<PaneSpan> spans) =>
    UnicodeWidth.stringWidth(spans.map((span) => span.text).join());

/// [spans] fitted to [cells] terminal cells, ending in an ellipsis in the
/// tone of the text it replaces when they overflow.
List<PaneSpan> paneSpansEllipsized(List<PaneSpan> spans, int cells) {
  var rest = spans
      .map((span) => span.text)
      .join()
      .ellipsizeCells(cells)
      .characters;
  final fitted = <PaneSpan>[];
  for (final span in spans) {
    final length = span.text.characters.length;
    fitted.add(PaneSpan(rest.take(length).string, span.tone));
    rest = rest.skip(length);
  }
  return fitted;
}

/// One line of [spans] that ends in an ellipsis when it overflows its width,
/// hugging the side [align] names.
@view
class EllipsizedSpanLine extends StatelessComponent {
  const EllipsizedSpanLine(
    this.spans, {
    this.align = PaneAlign.start,
    super.key,
  });

  final List<PaneSpan> spans;

  final PaneAlign align;

  @override
  Component build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cells = constraints.maxWidth.toInt();
      final fitted = paneSpansEllipsized(spans, cells);
      return SpanLine(
        paneSpans(AppTheme.of(context), switch (align) {
          PaneAlign.start => fitted,
          PaneAlign.end => [
            PaneSpan(' ' * (cells - paneSpansWidth(fitted))),
            ...fitted,
          ],
        }),
      );
    },
  );
}

/// One clipped line of styled text.
@view
class SpanLine extends StatelessComponent {
  const SpanLine(this.text, {super.key});

  final InlineSpan text;

  @override
  Component build(BuildContext context) => SizedBox(
    height: 1,
    child: ClipRect(
      child: RichText(text: text, softWrap: false, maxLines: 1),
    ),
  );
}

/// `A › B › C`: every part secondary, the last one bold, joined by muted
/// separators.
@view
class PaletteBreadcrumb extends StatelessComponent {
  const PaletteBreadcrumb(this.parts, {super.key});

  final List<String> parts;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SpanLine(
      TextSpan(
        children: [
          for (var index = 0; index < parts.length; index++) ...[
            if (index > 0)
              TextSpan(
                text: ' › ',
                style: TextStyle(color: theme.muted),
              ),
            TextSpan(
              text: parts[index],
              style: TextStyle(
                color: theme.secondary,
                fontWeight: index == parts.length - 1
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A group label in the cursor gutter's alignment with a faint rule running
/// from it to the card's edge, set [gap] lines below what comes before.
@view
class PaletteGroupHeader extends StatelessComponent {
  const PaletteGroupHeader(this.label, {this.gap = 1, super.key});

  final String label;
  final int gap;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Container(
      padding: EdgeInsets.only(top: gap.toDouble()),
      child: SizedBox(
        height: 1,
        child: Row(
          children: [
            const SizedBox(width: PaletteListRow.gutter),
            Text(
              label,
              style: TextStyle(color: theme.muted, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 1),
            Expanded(child: PaletteRule(color: theme.outline)),
          ],
        ),
      ),
    );
  }
}

/// A list row with a cursor gutter, a title line, an optional detail line
/// underneath, and an optional extra line under that.
@view
class PaletteListRow extends StatelessComponent {
  const PaletteListRow({
    required this.selected,
    required this.fill,
    required this.title,
    this.leading,
    this.leadingWidth = defaultLeadingWidth,
    this.trailing,
    this.detail,
    this.footer,
    super.key,
  });

  final bool selected;

  /// Background behind the text lines.
  final Color? fill;

  final Component title;
  final Component? leading;

  /// Cells [leading] spans, so the lines below indent past it.
  final double leadingWidth;
  final Component? trailing;
  final Component? detail;
  final Component? footer;

  /// Cells reserved for the selection cursor at the left of every row.
  static const double gutter = 2;
  static const double defaultLeadingWidth = 4;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final indent = gutter + (leading == null ? 0 : leadingWidth);
    return Container(
      color: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 1,
            child: Row(
              children: [
                SizedBox(
                  width: gutter,
                  child: Text(
                    selected ? '▸' : '',
                    style: TextStyle(color: theme.info),
                  ),
                ),
                ?leading,
                Expanded(child: title),
                ?trailing,
              ],
            ),
          ),
          for (final line in [?detail, ?footer])
            SizedBox(
              height: 1,
              child: Padding(
                padding: EdgeInsets.only(left: indent),
                child: line,
              ),
            ),
        ],
      ),
    );
  }
}

/// A one-row horizontal rule that stretches to its parent's width.
@view
class PaletteRule extends StatelessComponent {
  const PaletteRule({required this.color, super.key});

  final Color color;

  @override
  Component build(BuildContext context) => SizedBox(
    height: 1,
    child: LayoutBuilder(
      builder: (context, constraints) => Text(
        '─' * constraints.maxWidth.toInt(),
        style: TextStyle(color: color),
      ),
    ),
  );
}
