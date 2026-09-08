import 'package:meta/meta.dart';

/// Mouse tracking mode selected via DEC private modes 9 / 1000 /
/// 1002 / 1003. Stored but not actively encoded by this layer —
/// higher layers decide how to turn agent click events into bytes.
enum MouseMode {
  /// Mouse reporting off.
  off,

  /// X10 compatibility — report button presses only.
  x10,

  /// VT200 — report button press and release.
  vt200,

  /// Button-event tracking — report drags with a pressed button.
  buttonEvent,

  /// Any-event tracking — report all motion, pressed or not.
  anyEvent,
}

/// Encoding that mouse reports should use when this terminal
/// eventually produces them. DEC private modes 1005 / 1006 / 1015.
enum MouseEncoding {
  /// Legacy X10 encoding (single-byte coordinates, 6 + col / row).
  x10,

  /// UTF-8 encoding (1005).
  utf8,

  /// SGR-style text encoding (1006). The most common modern one.
  sgr,

  /// urxvt decimal encoding (1015).
  urxvt,
}

/// An immutable snapshot of [TerminalModes] at a moment in time.
typedef TerminalModesData = ({
  bool autoWrap,
  bool originMode,
  bool cursorKeysApp,
  bool cursorVisible,
  bool cursorBlink,
  bool reverseVideo,
  bool insertMode,
  bool bracketedPaste,
  bool focusReport,
  bool syncOutput,
  MouseMode mouseMode,
  MouseEncoding mouseEncoding,
});

/// Mutable struct holding the DEC private + ANSI mode state.
class TerminalModes {
  /// Create a TerminalModes with defaults matching a fresh
  /// xterm-256color terminal.
  TerminalModes();

  /// DECAWM (mode 7) — auto-wrap. Defaults to `true`.
  bool autoWrap = true;

  /// DECOM (mode 6) — origin mode. When `true`, cursor addressing
  /// is relative to the scroll region's top-left and the cursor
  /// is constrained inside it. Defaults to `false`.
  bool originMode = false;

  /// DECCKM (mode 1) — cursor-key application mode. Stored only;
  /// higher layers use it to decide which escape sequences to
  /// emit for arrow keys.
  bool cursorKeysApp = false;

  /// DECTCEM (mode 25) — cursor visibility. Defaults to `true`.
  bool cursorVisible = true;

  /// ATT610 (mode 12) — cursor blink.
  bool cursorBlink = true;

  /// DECSCNM (mode 5) — reverse video for the entire display.
  bool reverseVideo = false;

  /// IRM (ANSI mode 4) — insert mode.
  bool insertMode = false;

  /// Mode 2004 — bracketed paste.
  bool bracketedPaste = false;

  /// Mode 1004 — focus event reporting.
  bool focusReport = false;

  /// Mode 2026 — synchronized output. While `true`, the terminal
  /// is mid-frame-update and observers should defer snapshots.
  bool syncOutput = false;

  /// Active mouse-tracking mode.
  MouseMode mouseMode = MouseMode.off;

  /// Encoding for mouse reports.
  MouseEncoding mouseEncoding = MouseEncoding.x10;

  /// Capture the current mode state as an immutable record.
  @useResult
  TerminalModesData freeze() => (
    autoWrap: autoWrap,
    originMode: originMode,
    cursorKeysApp: cursorKeysApp,
    cursorVisible: cursorVisible,
    cursorBlink: cursorBlink,
    reverseVideo: reverseVideo,
    insertMode: insertMode,
    bracketedPaste: bracketedPaste,
    focusReport: focusReport,
    syncOutput: syncOutput,
    mouseMode: mouseMode,
    mouseEncoding: mouseEncoding,
  );
}
