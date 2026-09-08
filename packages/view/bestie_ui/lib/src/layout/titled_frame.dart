import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
// TerminalCanvas and BorderStyle aren't in nocterm's public exports; mirrors
// the direct import done by nocterm's own Divider / Padding renders.
// ignore: implementation_imports
import 'package:nocterm/src/framework/terminal_canvas.dart';

/// A block with a permanently reserved rim: a title row above the child, a
/// blank row below it, and two columns on either side.
///
/// The rim is where a gutter glyph or a whole frame gets painted, so turning
/// either on or off never moves the content. Unframed, [gutterGlyph] runs
/// down the left column beside the title and content rows. Framed, a heavy
/// box in [frameColor] wraps the block and the title sits in its top rule.
@view
class TitledFrame extends SingleChildRenderObjectComponent {
  const TitledFrame({
    required this.title,
    required this.titleStyle,
    required this.gutterGlyph,
    required this.gutterColor,
    required Component super.child,
    this.frameColor,
    super.key,
  });

  /// Columns reserved on each side of the child.
  static const double rimWidth = 2;

  final String title;
  final TextStyle titleStyle;

  /// One-character glyph painted beside each title and content row while
  /// unframed. Pass `' '` (single space) for an invisible gutter.
  final String gutterGlyph;
  final Color gutterColor;

  /// When set, the block is boxed in this color.
  final Color? frameColor;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTitledFrame(
    title: title,
    titleStyle: titleStyle,
    gutterGlyph: gutterGlyph,
    gutterColor: gutterColor,
    frameColor: frameColor,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    // The render object is intentionally private; this method is part of the
    // framework contract and only the framework calls it.
    // ignore: library_private_types_in_public_api
    _RenderTitledFrame renderObject,
  ) {
    renderObject.update(
      title: title,
      titleStyle: titleStyle,
      gutterGlyph: gutterGlyph,
      gutterColor: gutterColor,
      frameColor: frameColor,
    );
  }
}

class _RenderTitledFrame extends RenderObject
    with RenderObjectWithChildMixin<RenderObject> {
  _RenderTitledFrame({
    required String title,
    required TextStyle titleStyle,
    required String gutterGlyph,
    required Color gutterColor,
    required Color? frameColor,
  }) : _title = title,
       _titleStyle = titleStyle,
       _gutterGlyph = gutterGlyph,
       _gutterColor = gutterColor,
       _frameColor = frameColor;

  static const double _side = TitledFrame.rimWidth;
  static const double _top = 1;
  static const double _bottom = 1;
  static const _rim = EdgeInsets.symmetric(horizontal: _side, vertical: _top);

  String _title;
  TextStyle _titleStyle;
  String _gutterGlyph;
  Color _gutterColor;
  Color? _frameColor;

  /// Takes on a new look, repainting only when something differs.
  void update({
    required String title,
    required TextStyle titleStyle,
    required String gutterGlyph,
    required Color gutterColor,
    required Color? frameColor,
  }) {
    final unchanged =
        title == _title &&
        titleStyle == _titleStyle &&
        gutterGlyph == _gutterGlyph &&
        gutterColor == _gutterColor &&
        frameColor == _frameColor;
    if (unchanged) return;
    _title = title;
    _titleStyle = titleStyle;
    _gutterGlyph = gutterGlyph;
    _gutterColor = gutterColor;
    _frameColor = frameColor;
    markNeedsPaint();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    child?.layout(constraints.deflate(_rim), parentUsesSize: true);
    final childSize = child?.size ?? Size.zero;
    size = constraints.constrain(
      Size(childSize.width + _side * 2, childSize.height + _top + _bottom),
    );
  }

  @override
  void paint(TerminalCanvas canvas, Offset offset) {
    super.paint(canvas, offset);
    final localChild = child;
    if (localChild != null) {
      final childData = localChild.parentData! as BoxParentData
        ..offset = const Offset(_side, _top);
      localChild.paint(canvas, offset + childData.offset);
    }
    final frame = _frameColor;
    if (frame != null) {
      _paintFrame(canvas, offset, frame);
    } else {
      _paintGutter(canvas, offset);
    }
  }

  void _paintFrame(TerminalCanvas canvas, Offset offset, Color color) {
    canvas
      ..drawBox(
        Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
        border: BorderStyle.thick,
        style: TextStyle(color: color),
      )
      ..drawText(
        Offset(offset.dx + _side - 1, offset.dy),
        ' $_title ',
        style: _titleStyle,
      );
  }

  void _paintGutter(TerminalCanvas canvas, Offset offset) {
    final style = TextStyle(color: _gutterColor);
    for (double y = 0; y < size.height - _bottom; y += 1) {
      canvas.drawText(
        Offset(offset.dx, offset.dy + y),
        _gutterGlyph,
        style: style,
      );
    }
    canvas.drawText(
      Offset(offset.dx + _side, offset.dy),
      _title,
      style: _titleStyle,
    );
  }
}
