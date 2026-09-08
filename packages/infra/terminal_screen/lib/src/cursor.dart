import 'package:meta/meta.dart';
import 'package:terminal_screen/src/color.dart';

/// The terminal cursor's visual shape.
enum CursorStyle {
  /// Block cursor (DECSCUSR 1/2).
  block,

  /// Underline cursor (DECSCUSR 3/4).
  underline,

  /// Vertical bar cursor (DECSCUSR 5/6).
  bar,
}

/// Where a cursor sits on the grid.
@immutable
class CursorPosition {
  /// The position at [row], [col].
  const CursorPosition({required this.row, required this.col});

  /// Row (0-indexed).
  final int row;

  /// Column (0-indexed).
  final int col;
}

/// An immutable snapshot of the cursor's state at a moment in time.
typedef CursorData = ({
  int row,
  int col,
  bool visible,
  CursorStyle style,
  bool blinking,
  bool pendingWrap,
});

/// The mutable, live cursor. Held by `Screen` and mutated by its
/// ParserSink methods in response to CSI movement, ESC 7 / 8 save
/// and restore, DECSCUSR style changes, and DECTCEM visibility
/// toggles.
class Cursor {
  /// Create a cursor at the origin.
  Cursor();

  /// Current row (0-indexed).
  int row = 0;

  /// Current column (0-indexed).
  int col = 0;

  /// `true` if the cursor should be drawn.
  bool visible = true;

  /// Block / underline / bar.
  CursorStyle style = CursorStyle.block;

  /// Whether the cursor is blinking.
  bool blinking = true;

  /// The "pending wrap" flag: when auto-wrap (DECAWM) is on and a
  /// printable character lands in the last column, we leave the
  /// cursor on that last column and *mark* it pending wrap. The
  /// next printable advances to the next row before writing. This
  /// is the classic "wrap on the next char" semantics that lets
  /// you print into the rightmost column without prematurely
  /// scrolling.
  bool pendingWrap = false;

  // --- Saved state (ESC 7 / ESC 8 / CSI s / CSI u) ---------------

  /// `true` if there's a saved cursor state to restore.
  bool get hasSaved => _savedRow != null;

  int? _savedRow;
  int? _savedCol;
  Color? _savedFg;
  Color? _savedBg;
  int? _savedAttrs;
  bool? _savedOriginMode;
  bool? _savedPendingWrap;

  /// Save the current cursor state plus the arguments provided
  /// (which reflect the SGR + origin-mode state held elsewhere in
  /// the screen). DEC ops save the pen and origin mode together.
  void save({
    required Color fg,
    required Color bg,
    required int attrs,
    required bool originMode,
  }) {
    _savedRow = row;
    _savedCol = col;
    _savedFg = fg;
    _savedBg = bg;
    _savedAttrs = attrs;
    _savedOriginMode = originMode;
    _savedPendingWrap = pendingWrap;
  }

  /// Restore a previously-saved cursor state. If nothing was
  /// saved, the cursor jumps to the home position and the caller
  /// is expected to reset pen / origin mode to defaults; this
  /// method only mutates the cursor itself.
  ///
  /// Returns a record with the pen + origin-mode values the
  /// caller should apply elsewhere.
  ({Color fg, Color bg, int attrs, bool originMode, bool pendingWrap})
  restore() {
    if (_savedRow == null) {
      row = 0;
      col = 0;
      pendingWrap = false;
      return (
        fg: Color.defaultFg,
        bg: Color.defaultBg,
        attrs: 0,
        originMode: false,
        pendingWrap: false,
      );
    }
    row = _savedRow!;
    col = _savedCol!;
    pendingWrap = _savedPendingWrap!;
    return (
      fg: _savedFg!,
      bg: _savedBg!,
      attrs: _savedAttrs!,
      originMode: _savedOriginMode!,
      pendingWrap: _savedPendingWrap!,
    );
  }

  /// Where [restore] would put the cursor, or `null` when nothing is
  /// saved.
  @useResult
  CursorPosition? get savedPosition => _savedRow == null
      ? null
      : CursorPosition(row: _savedRow!, col: _savedCol!);

  /// Move the saved position to [row], [col], leaving the rest of the
  /// saved state alone. Ignored when nothing is saved.
  void relocateSaved({required int row, required int col}) {
    if (_savedRow == null) return;
    _savedRow = row;
    _savedCol = col;
  }

  /// Forget any saved cursor state.
  void forgetSaved() {
    _savedRow = null;
    _savedCol = null;
    _savedFg = null;
    _savedBg = null;
    _savedAttrs = null;
    _savedOriginMode = null;
    _savedPendingWrap = null;
  }

  /// Capture the cursor's public state as an immutable record.
  @useResult
  CursorData freeze() => (
    row: row,
    col: col,
    visible: visible,
    style: style,
    blinking: blinking,
    pendingWrap: pendingWrap,
  );
}
