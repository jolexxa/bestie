import 'package:bestie_ui/src/layout/tab_header.dart';
import 'package:bestie_ui/src/nav/app_mode.dart';
import 'package:bestie_ui/src/nav/router_context.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Compact 3-line header shared by all app modes.
///
/// Lines 1-2: mode tabs, with a riser cap over the active mode.
/// Line 3: page-specific stats/content.
@view
class ModeHeader extends StatelessComponent {
  /// Creates a [ModeHeader].
  const ModeHeader({this.content, super.key});

  /// Stats/content for the second row. Centered.
  final Component? content;

  @override
  Component build(BuildContext context) {
    final theme = TuiTheme.of(context);
    final router = Provider.of<RouterContext>(context);

    return SizedBox(
      height: 3,
      child: Column(
        children: [
          TabHeader<AppMode>(
            tabs: AppMode.modes,
            selected: router.mode,
            label: (mode) => mode.label.toUpperCase(),
            onSelect: router.switchToMode,
          ),
          Expanded(
            child: Container(
              color: theme.background,
              child: content ?? const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}
