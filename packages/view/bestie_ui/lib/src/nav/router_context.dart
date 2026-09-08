import 'package:bestie_ui/src/nav/app_mode.dart';
import 'package:intentions/intentions.dart';

/// Ambient routing facts that pages need to know.
///
/// Provided by the `Router` via `Provider<RouterContext>` so pages can
/// gate their focus and rendering on both the active mode and whether
/// a modal overlay (e.g. the config overlay) is currently open.
@model
class RouterContext {
  const RouterContext({
    required this.mode,
    required this.overlayOpen,
    required this.switchToMode,
  });

  /// The currently active app mode.
  final AppMode mode;

  /// Whether a modal overlay is currently covering the modes.
  final bool overlayOpen;

  /// Requests a switch to [AppMode]. Backed by the router's own cubit,
  /// which stays with the app rather than this shared UI layer.
  final void Function(AppMode mode) switchToMode;

  /// Whether the page belonging to [pageMode] should currently hold focus.
  ///
  /// True only when the page's mode is the active mode AND no modal
  /// overlay is open above it.
  bool focusFor(AppMode pageMode) => mode == pageMode && !overlayOpen;
}
