import 'package:bestie_chat_view/src/view/components/chat_input_row.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

/// Stands in for the text field until the sandbox is initialized, taking the
/// same room.
@view
class SandboxGateRow extends StatelessComponent {
  const SandboxGateRow({required this.readiness, super.key});

  final SandboxReadiness readiness;

  /// What the gate says for [readiness].
  static String hintFor(SandboxReadiness readiness) => switch (readiness) {
    SandboxAwaitingInitialization() =>
      'Press Enter to initialize the sandbox (one-time administrator '
          'privileges required). This can take a few minutes on Windows.',
    SandboxPreparingHost() =>
      'Initializing the sandbox… this can take a few minutes on Windows.',
    SandboxProvisioning() => 'Provisioning the sandbox…',
    SandboxInitializationFailed(:final reason) =>
      'Sandbox initialization failed: $reason. Press Enter to try again.',
    SandboxReady() => '',
  };

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final failed = readiness is SandboxInitializationFailed;
    final accent = failed ? theme.error : theme.accent;
    return SizedBox(
      height: ChatInputRow.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⛨ ', style: TextStyle(color: accent)),
          Text(
            'Sandbox',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              hintFor(readiness),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.muted),
            ),
          ),
        ],
      ),
    );
  }
}
