import 'package:intentions/intentions.dart';

/// Inputs to the shell pane logic block.
@model
sealed class ShellPaneInput {
  const ShellPaneInput();
}

/// What the surface would draw may have changed. One input for every cause,
/// carrying nothing — the surface is the authority on how it looks now.
@model
final class SurfaceChanged extends ShellPaneInput {
  const SurfaceChanged();
}

/// Move the scrollback viewport by [rows]; positive scrolls up into history.
@model
final class ScrollView extends ShellPaneInput {
  const ScrollView(this.rows);

  final int rows;
}

/// Snap the viewport back to the live region — typing means the user wants
/// to see what they are typing at.
@model
final class FollowOutput extends ShellPaneInput {
  const FollowOutput();
}

/// Send [bytes] to the child's stdin.
@model
final class WriteToChild extends ShellPaneInput {
  const WriteToChild(this.bytes);

  final List<int> bytes;
}

/// The surface was laid out at a new cell size.
@model
final class ResizeSurface extends ShellPaneInput {
  const ResizeSurface({required this.rows, required this.cols});

  final int rows;
  final int cols;
}
