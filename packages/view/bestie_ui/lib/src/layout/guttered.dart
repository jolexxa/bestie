import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
// TerminalCanvas isn't in nocterm's public exports; mirrors the direct
// import done by nocterm's own Divider / Padding renders.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';

/// Wraps a child with a 2-col left gutter that paints [glyph] on every
/// visual row of the child's height.
///
/// Use to draw a continuous vertical indicator (selection / modified bar)
/// that spans any block, including multi-line content like wrapped text
/// or a `maxLines: N` editor.
@view
class Guttered extends SingleChildRenderObjectComponent {
  const Guttered({
    required this.glyph,
    required this.color,
    required Component super.child,
    super.key,
  });

  /// One-character glyph painted on each row in the gutter column.
  /// Pass `' '` (single space) for an invisible gutter that still
  /// reserves its 2-col footprint.
  final String glyph;

  /// Color of the gutter glyph.
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGuttered(glyph: glyph, color: color);

  @override
  // The render object is intentionally private; this method is part of the
  // framework contract and only the framework calls it.
  // ignore: library_private_types_in_public_api
  void updateRenderObject(BuildContext context, _RenderGuttered renderObject) {
    renderObject
      ..glyph = glyph
      ..color = color;
  }
}

class _RenderGuttered extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  _RenderGuttered({required String glyph, required Color color})
    : _glyph = glyph,
      _color = color;

  String _glyph;
  String get glyph => _glyph;
  set glyph(String value) {
    if (_glyph != value) {
      _glyph = value;
      markNeedsPaint();
    }
  }

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (_color != value) {
      _color = value;
      markNeedsPaint();
    }
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    final inner = constraints.deflate(const EdgeInsets.only(left: 2));
    child?.layout(inner, parentUsesSize: true);
    final childSize = child?.size ?? Size.zero;
    size = constraints.constrain(
      Size(childSize.width + 2, childSize.height),
    );
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    final localChild = child;
    if (localChild != null) {
      final childData = localChild.parentData! as BoxParentData
        ..offset = const Offset(2, 0);
      localChild.paint(canvas, offset + childData.offset);
    }
    for (double y = 0; y < size.height; y += 1) {
      canvas.drawText(
        Offset(offset.dx, offset.dy + y),
        glyph,
        style: TextStyle(color: color),
      );
    }
  }
}
