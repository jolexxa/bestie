import 'dart:async';

import 'package:bestie_chat_view/src/workspace/interactive_terminal_view.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_cubit.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_state.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:shell_repository/shell_repository.dart';

/// Draws a [TerminalSurface], framed by a box that highlights while the pane
/// holds the keyboard. Read-only ([interactive] `false`) ignores [focused];
/// interactive forwards keystrokes while [focused]. Holds no lifecycle over it.
@view
class ShellPane extends StatefulComponent {
  const ShellPane({
    required this.surface,
    this.focused = false,
    this.interactive = true,
    this.onHoverChanged,
    super.key,
  });

  /// What to render and, when [interactive], write to.
  final TerminalSurface surface;

  /// Whether this pane owns the keyboard right now.
  final bool focused;

  /// `false` renders a read-only viewer with no input routing at all.
  final bool interactive;

  /// Reports the mouse entering or leaving this pane's box.
  final void Function({required bool hovered})? onHoverChanged;

  @override
  State<ShellPane> createState() => _ShellPaneState();
}

class _ShellPaneState extends State<ShellPane> {
  late final ShellPaneCubit _cubit = ShellPaneCubit(
    logic: ShellPaneLogic(surface: component.surface),
  );

  final GlobalKey _gridKey = GlobalKey();

  bool _hovered = false;

  @override
  void dispose() {
    if (_hovered) component.onHoverChanged?.call(hovered: false);
    unawaited(_cubit.close());
    super.dispose();
  }

  void _copyToClipboard(BuildContext context, String text) {
    if (text.isEmpty) return;
    unawaited(
      RepositoryProvider.of<OSPlatformRepository>(
        context,
      ).copyToClipboard(text),
    );
  }

  /// The frame is the one border the chat keeps: it says where keystrokes go.
  /// Always drawn so focus never reflows the child; unfocused it paints in the
  /// background color.
  Component _framed(BuildContext context, Component child) {
    final appTheme = AppTheme.of(context);
    return MouseRegion(
      onEnter: (_) {
        _hovered = true;
        component.onHoverChanged?.call(hovered: true);
      },
      onExit: (_) {
        _hovered = false;
        component.onHoverChanged?.call(hovered: false);
      },
      child: component.interactive
          ? Container(
              decoration: BoxDecoration(
                border: BoxBorder.all(
                  color: component.focused
                      ? appTheme.primary
                      : appTheme.background,
                ),
              ),
              child: child,
            )
          : Container(color: appTheme.background, child: child),
    );
  }

  void _resize({required int rows, required int cols}) =>
      _cubit.resize(rows: rows, cols: cols);

  Component _surface(BuildContext context, ShellPaneReady state) {
    if (!component.interactive) {
      return TerminalView(
        screen: state.screen,
        showCursor: state.showCursor,
        onResize: _resize,
        onSelectionCompleted: (text) => _copyToClipboard(context, text),
      );
    }
    return InteractiveTerminalView(
      screen: state.screen,
      focused: component.focused,
      gridKey: _gridKey,
      cubit: _cubit,
      onSelectionCompleted: (text) => _copyToClipboard(context, text),
    );
  }

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return BlocBuilder<ShellPaneCubit, ShellPaneState>(
      bloc: _cubit,
      builder: (context, state) => _framed(
        context,
        switch (state) {
          ShellPaneSpawning() => Center(
            child: Text('Starting…', style: TextStyle(color: theme.muted)),
          ),
          final ShellPaneReady ready => _surface(context, ready),
        },
      ),
    );
  }
}
