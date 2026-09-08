import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/message_item_layout.dart';
import 'package:bestie_chat_view/src/view/details/item_details_mapping.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart' hide MarkdownStyleSheet, MarkdownText;

/// Renders a [MessageTimelineItem] in the main chat pane.
@view
class MessageItem extends StatelessComponent {
  const MessageItem({
    required this.item,
    this.selected = false,
    this.hovered = false,
    this.frame = MessageFrame.none,
    super.key,
  });

  final MessageTimelineItem item;

  final bool selected;
  final bool hovered;

  final MessageFrame frame;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);

    final (senderColor, messageColor, accentColor) = item.role == Role.user
        ? (theme.success, theme.onBackground, theme.secondary)
        : (theme.primary, theme.onBackground, theme.secondary);

    final children = <Component>[];

    // Contiguous paragraph runs must rejoin verbatim before markdown
    // rendering.
    final paragraph = StringBuffer();
    void flushParagraph() {
      if (paragraph.isEmpty) return;
      children.add(
        _markdownRow(paragraph.toString(), theme, messageColor, accentColor),
      );
      paragraph.clear();
    }

    for (final block in item.blocks) {
      if (block is TranscriptParagraphBlock) {
        paragraph.write(block.text);
      } else {
        flushParagraph();
      }
    }
    flushParagraph();

    if (children.isEmpty) {
      children.add(_mutedRow('(no content)', theme));
    }

    return MessageItemLayout(
      senderLabel: senderLabelFor(item.role),
      senderColor: senderColor,
      showSpinner: item.running,
      selected: selected,
      hovered: hovered,
      frame: frame,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Component _markdownRow(
    String text,
    AppThemeData theme,
    Color messageColor,
    Color accentColor,
  ) {
    return Row(
      children: [
        Expanded(
          child: MarkdownView(
            text,
            theme: MarkdownTheme(
              paragraphStyle: TextStyle(color: messageColor),
              boldStyle: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            highlightTheme: syntaxThemeFor(theme),
            streaming: item.running,
          ),
        ),
      ],
    );
  }

  Component _mutedRow(String text, AppThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(text, style: TextStyle(color: theme.muted)),
        ),
      ],
    );
  }
}
