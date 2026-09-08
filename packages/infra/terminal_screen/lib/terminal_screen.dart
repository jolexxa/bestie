/// Live cell grid + snapshot/diff/waitFor agent API for the
/// agentic_terminal stack.
library;

export 'src/attrs.dart' show CellAttrs, CellWidth, UnderlineStyle;
export 'src/cell.dart' show CellData;
export 'src/color.dart'
    show Color, DefaultBackground, DefaultForeground, IndexedColor, RgbColor;
export 'src/cursor.dart' show Cursor, CursorData, CursorStyle;
export 'src/diff.dart' show CellChange, ScreenDiff, computeDiff;
export 'src/line_bytes.dart' show LineBytes, LineSink;
export 'src/line_writer.dart' show LineWriter;
export 'src/modes.dart'
    show MouseEncoding, MouseMode, TerminalModes, TerminalModesData;
export 'src/packed_cell.dart'
    show
        ColorKind,
        colorBlue,
        colorGreen,
        colorIndex,
        colorKind,
        colorRed,
        packColor,
        packedDefaultBg,
        packedDefaultFg,
        unpackColor;
export 'src/pen_codec.dart' show penToAnsi, readPen, writePenRun;
export 'src/region.dart' show Region;
export 'src/resize_behavior.dart'
    show ReflowingResize, RepaintingResize, ResizeBehavior;
export 'src/screen.dart' show Screen;
export 'src/selection_anchor.dart' show SelectionAnchor;
export 'src/selection_text.dart' show SelectionMetrics, SelectionText;
export 'src/sgr_encode.dart' show writeSgr;
export 'src/snapshot.dart' show ScreenSnapshot;
