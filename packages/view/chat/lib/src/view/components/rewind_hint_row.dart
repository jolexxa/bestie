import 'package:bestie_chat_view/src/view/components/chat_input_row.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Stands in for the text field while the user picks a message to rewind to.
/// Takes the same room, so the chat list holds still.
@view
class RewindHintRow extends StatelessComponent {
  const RewindHintRow({super.key});

  static const String hint =
      '↑/↓ pick a message · Enter or click to rewind · Esc to cancel';

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return SizedBox(
      height: ChatInputRow.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⟲ ', style: TextStyle(color: theme.error)),
          Text(
            'Rewind',
            style: TextStyle(color: theme.error, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              hint,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.muted),
            ),
          ),
        ],
      ),
    );
  }
}
