import 'dart:math' as math;

import 'package:agent_repository/agent_repository.dart'
    show primaryAgentSessionId;
import 'package:bestie_chat_view/src/state/models/write_access_choice.dart';
import 'package:bestie_chat_view/src/view/components/chat_input_row.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Stands in for the text field while an agent's ask for write access
/// awaits the user, taking the same room: a glittering title bar in the
/// error color so it cannot be missed, the question, and the two answers as
/// buttons that keys or the mouse can press.
@view
class WriteAccessPromptRow extends StatefulComponent {
  const WriteAccessPromptRow({
    required this.request,
    required this.choice,
    required this.onAllow,
    required this.onDeny,
    this.random,
    super.key,
  });

  /// What the title bar says.
  static const String title = '⛨ Write access requested';

  /// The captions of the two answers.
  static const String allowLabel = 'y Allow';
  static const String denyLabel = 'n Deny';

  /// Cells between the two buttons.
  static const double buttonGap = 2;

  /// Rows kept for the question, so the answers always sit at the bottom of
  /// the slot however long the path is.
  static const int questionRows = 2;

  /// Cells between the bar's left edge and the title.
  static const int inset = 1;

  /// The question put to the user for [request].
  static String questionFor(WriteAccessRequest request) =>
      'Allow spawned processes to write to ${request.shownPath} during '
      'normal agent operations?';

  /// Who is asking, in the user's terms.
  static String askerFor(WriteAccessRequest request) =>
      request.agentId == primaryAgentSessionId
      ? 'the main agent'
      : 'a subagent';

  final WriteAccessRequest request;

  /// Which answer keyboard focus rests on.
  final WriteAccessChoice choice;

  /// The answers, pressed by mouse.
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  /// Passed through to the glitter for deterministic tests.
  final math.Random? random;

  @override
  State<WriteAccessPromptRow> createState() => _WriteAccessPromptRowState();
}

class _WriteAccessPromptRowState extends State<WriteAccessPromptRow>
    with GlitterClock {
  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final request = component.request;
    final muted = TextStyle(color: theme.muted);
    return SizedBox(
      height: ChatInputRow.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GlitterField(
                    tick: tick,
                    random: component.random,
                    palette: GlitterPalette.error,
                  ),
                ),
                Positioned(
                  left: WriteAccessPromptRow.inset.toDouble(),
                  top: 0,
                  child: Text(
                    ' ${WriteAccessPromptRow.title} ',
                    style: TextStyle(
                      color: theme.onError,
                      backgroundColor: theme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: WriteAccessPromptRow.questionRows.toDouble(),
            child: Text(
              WriteAccessPromptRow.questionFor(request),
              maxLines: WriteAccessPromptRow.questionRows,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.onBackground),
            ),
          ),
          Text(
            'Reason: ${request.reason}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
          Text(
            'Asked by: ${WriteAccessPromptRow.askerFor(request)}',
            style: muted,
          ),
          Row(
            children: [
              AppButton(
                label: WriteAccessPromptRow.allowLabel,
                onPressed: component.onAllow,
                color: theme.error,
                onColor: theme.onError,
                selected: component.choice.allows,
                dense: true,
              ),
              const SizedBox(width: WriteAccessPromptRow.buttonGap),
              AppButton(
                label: WriteAccessPromptRow.denyLabel,
                onPressed: component.onDeny,
                selected: !component.choice.allows,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
