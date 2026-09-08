import 'package:nocterm/nocterm.dart';

/// [child] over a [background] painted at the box layer, so the colour
/// reaches the edge of the pane rather than stopping at the last glyph of
/// each line. [child] alone when there is no colour to paint.
Component paintBackdrop(Component child, Color? background) =>
    background == null
    ? child
    : DecoratedBox(
        decoration: BoxDecoration(color: background),
        child: child,
      );
