import 'package:bestie_chat_view/src/state/chat_cubit.dart';
import 'package:bestie_chat_view/src/state/chat_logic.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Shows context window usage as `used/total` tokens, muted until the
/// remaining budget runs low.
@view
class ContextIndicatorComponent extends StatelessComponent {
  const ContextIndicatorComponent({super.key});

  static const int _warningPercent = 20;
  static const int _errorPercent = 10;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final stats = state.stats;
        if (stats == null) return const SizedBox();
        final remaining = stats.remainingPercent;
        final color = remaining < _errorPercent
            ? theme.error
            : remaining < _warningPercent
            ? theme.warning
            : theme.muted;
        return Text(
          '${stats.cachedTokens.asCompactTokens}/'
          '${stats.contextSize.asCompactTokens}',
          style: TextStyle(color: color),
        );
      },
    );
  }
}
