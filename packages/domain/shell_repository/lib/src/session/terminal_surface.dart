import 'package:intentions/intentions.dart';
import 'package:terminal_screen/terminal_screen.dart';

/// Something a terminal view can draw, scroll, and be sized against.
@model
abstract interface class TerminalSurface {
  /// Fires whenever what to draw may have changed: output arrived, the
  /// lifecycle moved, the content re-wrapped.
  Stream<void> get changes;

  /// The rendered output, or null before there is any to draw.
  Screen? get screen;

  /// Whether whatever was behind the surface has finished, leaving [screen] a
  /// transcript rather than a live terminal.
  bool get exited;

  /// How far the displayed viewport sits above the live region, in rows.
  int get viewOffset;

  /// Scrolls to [offset], clamped to what the scrollback holds. Answers with
  /// the offset actually taken, so a caller can tell whether it moved.
  int setViewOffset(int offset);

  /// Sends [bytes] to whatever is behind the surface, if anything is.
  void write(List<int> bytes);

  /// Tells the surface the size it is being drawn at.
  void resize({required int rows, required int cols});
}
