import 'package:bestie_ui/src/layout/app_modal_barrier.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A full-screen overlay slot for a [Stack]. Renders [child] behind an
/// [AppModalBarrier] when [open], otherwise occupies no space.
///
/// Always returns a [Positioned.fill] so it's safe to keep as an
/// unconditional entry in a [Stack]'s `children`, regardless of [open].
@view
class FullScreenModal extends StatelessComponent {
  /// Creates a [FullScreenModal].
  const FullScreenModal({
    required this.open,
    required this.child,
    this.onDismiss,
    super.key,
  });

  /// Whether the modal is currently showing.
  final bool open;

  /// The modal's content, shown only while [open].
  final Component child;

  /// Called when a click lands outside [child].
  final VoidCallback? onDismiss;

  @override
  Component build(BuildContext context) => Positioned.fill(
    child: open
        ? AppModalBarrier(onDismiss: onDismiss, child: child)
        : const SizedBox(),
  );
}
