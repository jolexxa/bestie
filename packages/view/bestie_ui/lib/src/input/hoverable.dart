import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Adds mouse affordances to a list item without imposing any visuals of its
/// own.
@view
class Hoverable extends StatefulComponent {
  const Hoverable({
    required this.builder,
    this.onTap,
    this.onActivate,
    super.key,
  });

  /// Builds the wrapped content for the current hover state.
  final Component Function(BuildContext context, {required bool hovered})
  builder;

  /// Called on a single click — the equivalent of moving selection here.
  final VoidCallback? onTap;

  /// Called on a double click — the equivalent of pressing Enter.
  final VoidCallback? onActivate;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;

  void _setHovered({required bool value}) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Component build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(value: true),
      onExit: (_) => _setHovered(value: false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onTap: component.onTap,
        onDoubleTap: component.onActivate,
        child: component.builder(context, hovered: _hovered),
      ),
    );
  }
}
