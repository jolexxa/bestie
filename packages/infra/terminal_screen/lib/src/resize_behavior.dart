/// The rows a re-wrap has just written, oldest first.
abstract interface class WrittenRows {
  /// Rows written, counting any the wrap-around discarded.
  int get count;

  /// `true` when [row] continues the row above it.
  bool continuesAbove(int row);
}

/// What placing the new viewport depends on.
class ReflowAnchor {
  /// Describes one finished re-wrap.
  const ReflowAnchor({
    required this.rows,
    required this.seam,
    required this.oldest,
    required this.oldRows,
    required this.newRows,
    required this.cursorRow,
    required this.cursorLanded,
    required this.narrowing,
  });

  /// The rows the pass wrote.
  final WrittenRows rows;

  /// Where the row that was at the top of the viewport ended up.
  final int seam;

  /// Oldest row the ring still holds.
  final int oldest;

  /// Viewport height before the resize.
  final int oldRows;

  /// Viewport height after it.
  final int newRows;

  /// The cursor's viewport row before the resize, or null when the
  /// buffer carried no cursor.
  final int? cursorRow;

  /// Where the cursor ended up, or null when it carried none.
  final int? cursorLanded;

  /// Whether the re-wrap was to a narrower width.
  final bool narrowing;

  /// The row that would put the last written row at the bottom.
  int get bottom => rows.count - newRows;

  /// Index of the last row holding text.
  int get maxRow => rows.count - 1;
}

/// How a resize treats the grid, which depends on what the child does
/// once it has been told the new size.
sealed class ResizeBehavior {
  const ResizeBehavior();

  /// Where the new viewport begins among the rows a re-wrap wrote.
  int viewportStart(ReflowAnchor anchor);

  /// Whether a taller viewport takes rows back from history.
  bool get revealsHistoryOnGrow;

  /// Whether the main buffer waits until the alt screen is put away
  /// before it re-wraps.
  bool get defersMainBufferOnAltScreen;
}

/// The child is told the new size and leaves the grid alone.
final class ReflowingResize extends ResizeBehavior {
  /// The behaviour of a pty that only delivers the new size.
  const ReflowingResize();

  @override
  bool get revealsHistoryOnGrow => true;

  @override
  bool get defersMainBufferOnAltScreen => false;

  @override
  int viewportStart(ReflowAnchor anchor) {
    final bottom = anchor.bottom;
    final lowest = bottom > anchor.oldest ? bottom : anchor.oldest;
    final cursorRow = anchor.cursorRow;
    // With no cursor there is no room below it to protect, so the newest
    // rows are simply the ones shown.
    final anchorBottom = cursorRow == null || cursorRow == anchor.oldRows - 1;
    return !anchorBottom && anchor.seam > lowest ? anchor.seam : lowest;
  }
}

/// The child re-wraps a buffer of its own and repaints the viewport from
/// the top afterwards, so the seam has to end up where the child's did.
final class RepaintingResize extends ResizeBehavior {
  /// The behaviour of a pty that redraws what it thinks is on screen.
  const RepaintingResize();

  @override
  bool get revealsHistoryOnGrow => false;

  @override
  bool get defersMainBufferOnAltScreen => true;

  @override
  int viewportStart(ReflowAnchor anchor) {
    final seam = anchor.seam;
    final bottom = anchor.bottom;
    // Whatever reached history stays in history: the child has already
    // forgotten those rows and will not paint them again.
    var top = bottom > seam ? bottom : seam;

    // The seam names where the old top row *ended*. If that row wrapped,
    // its start is a row higher, and that is what the child is showing.
    if (top == seam &&
        anchor.narrowing &&
        top > 0 &&
        anchor.rows.continuesAbove(top)) {
      top--;
    }

    // Text running past the bottom of a viewport placed at the seam means
    // the seam is too high to show all of it.
    if (anchor.maxRow > seam + anchor.newRows - 1) top = bottom;

    if (top < anchor.oldest) top = anchor.oldest;

    // The cursor names where the child's next output goes, so its row has
    // to be one the viewport actually holds. Seam-anchoring can leave it
    // either side: above the top when history grew, and below the bottom
    // when the cursor sits on the empty row past the last line and the
    // re-wrap pushed that row out of reach. A cursor left outside gets
    // clamped onto some other row and prints into the middle of it.
    final landed = anchor.cursorLanded;
    if (landed != null) {
      if (top > landed) top = landed;
      final lowestShowing = landed - anchor.newRows + 1;
      if (top < lowestShowing) top = lowestShowing;
    }
    return top;
  }
}
