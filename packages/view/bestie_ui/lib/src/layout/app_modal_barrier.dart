import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Wraps a modal [child] with a full-screen barrier that absorbs mouse hover
/// and clicks, so the interactive content behind the modal doesn't light up
/// under the cursor or respond to clicks that miss the modal.
@view
class AppModalBarrier extends StatelessComponent {
  const AppModalBarrier({
    required this.child,
    this.dim,
    this.onDismiss,
    super.key,
  });

  /// The modal content, drawn on top of the barrier.
  final Component child;

  /// Optional scrim color painted over the background behind [child].
  final Color? dim;

  /// Called when a click lands on the barrier rather than on [child].
  final VoidCallback? onDismiss;

  @override
  Component build(BuildContext context) {
    final Component barrier = dim == null
        ? const SizedBox.expand()
        : ColoredBox(color: dim!, child: const SizedBox.expand());

    return Stack(
      children: [
        Positioned.fill(
          // Opaque (MouseRegion's default) so the hit-test stops here and
          // never reaches the interactive content behind the modal.
          child: MouseRegion(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: barrier,
            ),
          ),
        ),
        // Fill so [child] keeps the tight, full-screen constraints it had
        // before this barrier wrapped it. As a bare (non-positioned) Stack
        // child it would get loose constraints instead, which makes a
        // shrink-wrapping overlay (Center + a min-height Column with an
        // Expanded) re-layout every frame — a loop that visibly dances the
        // terminal cursor.
        Positioned.fill(child: child),
      ],
    );
  }
}
