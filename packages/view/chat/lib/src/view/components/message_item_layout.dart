import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Common layout for message-like rows in the chat.
///
/// The sender heads the block on its own line, above a body that gets the
/// full width to flow into.
/// How hard a message's rim calls it out.
enum MessageFrame {
  /// Just the selection bar.
  none,

  /// A quiet box, for a message the pointer could pick.
  subtle,

  /// A box in the alert color, for a choice with teeth.
  alert,
}

@view
class MessageItemLayout extends StatelessComponent {
  const MessageItemLayout({
    required this.senderLabel,
    required this.senderColor,
    required this.content,
    this.showSpinner = false,
    this.selected = false,
    this.hovered = false,
    this.frame = MessageFrame.none,
    super.key,
  });

  final String senderLabel;
  final Color senderColor;
  final Component content;
  final bool showSpinner;
  final bool selected;
  final bool hovered;

  final MessageFrame frame;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 1),
        SizedBox(width: 1, child: showSpinner ? const InlineSpinner() : null),
        const SizedBox(width: 1),
        Expanded(
          child: TitledFrame(
            title: senderLabel,
            titleStyle: TextStyle(
              color: senderColor,
              fontWeight: FontWeight.bold,
            ),
            gutterGlyph: selected || hovered ? '┃' : ' ',
            gutterColor: selected ? theme.primary : theme.muted,
            frameColor: switch (frame) {
              MessageFrame.none => null,
              MessageFrame.subtle => theme.muted,
              MessageFrame.alert => theme.error,
            },
            child: content,
          ),
        ),
      ],
    );
  }
}
