/// One decoded mouse event: a button press/release, motion, or
/// wheel tick. Coordinates are 1-based, matching the on-the-wire
/// encoding.
class MouseEvent {
  /// Create a mouse event.
  const MouseEvent({
    required this.button,
    required this.press,
    required this.col,
    required this.row,
    required this.shift,
    required this.alt,
    required this.ctrl,
  });

  /// Which button (or wheel direction) this event refers to.
  final MouseButton button;

  /// `true` for press/down (`M` terminator); `false` for release
  /// (`m` terminator). Wheel ticks always arrive as press.
  final bool press;

  /// 1-based column.
  final int col;

  /// 1-based row.
  final int row;

  /// Modifier states captured in the button code.
  final bool shift;

  /// Alt/meta modifier captured in the button code.
  final bool alt;

  /// Ctrl modifier captured in the button code.
  final bool ctrl;
}

/// Logical mouse button identity decoded from the protocol's
/// button code. Wheel ticks are encoded as buttons in xterm.
enum MouseButton {
  /// Primary button.
  left,

  /// Middle / wheel-press button.
  middle,

  /// Secondary button.
  right,

  /// Generic release (X10 reports all releases as button 3).
  release,

  /// Wheel scrolled up (away from user).
  wheelUp,

  /// Wheel scrolled down (toward user).
  wheelDown,

  /// Horizontal wheel left.
  wheelLeft,

  /// Horizontal wheel right.
  wheelRight,
}

/// Result of [parseHostInput]. Carries multiple representations
/// of the input so the caller can choose:
///
/// - Forward [bytesAsIs] when the child wants the raw mouse stream.
/// - Use [bytesWithWheelStripped] when the host owns wheel events
///   (e.g. scrollback navigation) but the child still wants
///   button/motion events.
/// - Use [bytesWithMouseStripped] when the child has no mouse
///   tracking and the host is fully consuming mouse data itself.
class HostInputParse {
  /// Construct a parse result.
  const HostInputParse({
    required this.bytesAsIs,
    required this.bytesWithMouseStripped,
    required this.bytesWithWheelStripped,
    required this.mouseEvents,
  });

  /// Original input bytes, unchanged.
  final List<int> bytesAsIs;

  /// Bytes with every recognised mouse sequence removed.
  final List<int> bytesWithMouseStripped;

  /// Bytes with only wheel (scroll) events removed — button and
  /// motion mouse events are preserved.
  final List<int> bytesWithWheelStripped;

  /// Mouse events in arrival order.
  final List<MouseEvent> mouseEvents;
}

/// Parse a stdin chunk: separate mouse sequences from non-mouse
/// keyboard bytes and decode the mouse sequences into structured
/// events.
///
/// Recognises:
/// - SGR mouse: `ESC [ <` params `M`/`m` (variable length)
/// - X10 mouse: `ESC [ M` + 3 bytes (6 bytes total)
///
/// An incomplete or malformed mouse sequence is left in
/// [HostInputParse.bytesWithMouseStripped] as-is — the same
/// best-effort tolerance the original strip-only implementation
/// shipped with.
HostInputParse parseHostInput(List<int> bytes) {
  final stripped = <int>[];
  final wheelStripped = <int>[];
  final events = <MouseEvent>[];
  var i = 0;
  while (i < bytes.length) {
    if (i + 2 < bytes.length && bytes[i] == 0x1B && bytes[i + 1] == 0x5B) {
      // SGR mouse: ESC [ < ... M/m
      if (bytes[i + 2] == 0x3C) {
        var j = i + 3;
        var validSgr = true;
        while (j < bytes.length && bytes[j] != 0x4D && bytes[j] != 0x6D) {
          final b = bytes[j];
          if (!((b >= 0x30 && b <= 0x39) || b == 0x3B)) {
            validSgr = false;
            break;
          }
          j++;
        }
        if (validSgr && j < bytes.length) {
          final ev = _decodeSgrMouse(bytes, i + 3, j);
          if (ev != null) events.add(ev);
          // Non-wheel mouse sequences survive in wheelStripped so
          // that an app subscribed to mouse tracking still gets
          // its clicks even though we ate the wheel.
          if (ev == null || !_isWheel(ev.button)) {
            for (var k = i; k <= j; k++) {
              wheelStripped.add(bytes[k]);
            }
          }
          i = j + 1;
          continue;
        }
        // Not a valid SGR mouse sequence — emit ESC [ < as-is.
        stripped.addAll(const [0x1B, 0x5B, 0x3C]);
        wheelStripped.addAll(const [0x1B, 0x5B, 0x3C]);
        i += 3;
        continue;
      }
      // X10 mouse: ESC [ M + 3 data bytes = 6 total
      if (bytes[i + 2] == 0x4D && i + 5 < bytes.length) {
        final ev = _decodeX10Mouse(bytes[i + 3], bytes[i + 4], bytes[i + 5]);
        events.add(ev);
        if (!_isWheel(ev.button)) {
          for (var k = i; k < i + 6; k++) {
            wheelStripped.add(bytes[k]);
          }
        }
        i += 6;
        continue;
      }
    }
    stripped.add(bytes[i]);
    wheelStripped.add(bytes[i]);
    i++;
  }
  return HostInputParse(
    bytesAsIs: bytes,
    bytesWithMouseStripped: stripped,
    bytesWithWheelStripped: wheelStripped,
    mouseEvents: events,
  );
}

bool _isWheel(MouseButton button) =>
    button == MouseButton.wheelUp ||
    button == MouseButton.wheelDown ||
    button == MouseButton.wheelLeft ||
    button == MouseButton.wheelRight;

/// Strip mouse tracking sequences from a byte buffer, keeping
/// all non-mouse bytes. Thin wrapper over [parseHostInput] for
/// callers that only need the byte view.
List<int> stripMouseSequences(List<int> bytes) =>
    parseHostInput(bytes).bytesWithMouseStripped;

/// The gesture a [MouseGestureRouter] is mid-way through forwarding.
class _Gesture {
  _Gesture({
    required this.cb,
    required this.sgr,
    required this.col,
    required this.row,
  });

  final int cb;
  final bool sgr;
  int col;
  int row;
}

/// Routes host mouse sequences to a child terminal occupying a sub-region
/// of the host's screen, with real pointer-capture semantics so the child
/// never sees half a gesture.
class MouseGestureRouter {
  _Gesture? _gesture;

  /// Whether a button gesture that began inside the region is in flight.
  bool get capturing => _gesture != null;

  /// Routes one stdin chunk for a child region whose top-left cell sits at
  /// 0-based ([dx], [dy]) in host coordinates and spans [maxCol] × [maxRow]
  /// child cells. Returns the bytes to forward: non-mouse bytes pass
  /// through in place, surviving mouse sequences carry translated
  /// coordinates.
  List<int> route(
    List<int> bytes, {
    required int dx,
    required int dy,
    required int maxCol,
    required int maxRow,
    bool wheelOnly = false,
  }) {
    final out = <int>[];

    // Entering wheel-only routing mid-gesture means focus moved on while a
    // button was down — close the gesture out for the child.
    if (wheelOnly) _heal(out);

    void routeEvent({
      required int cb,
      required int col,
      required int row,
      required bool release,
      required bool sgr,
      required int limitCol,
      required int limitRow,
      required List<int> Function(int cb, int col, int row) emit,
    }) {
      final tCol = col - dx;
      final tRow = row - dy;
      final inside =
          tCol >= 1 && tRow >= 1 && tCol <= limitCol && tRow <= limitRow;

      if ((cb & 0x40) != 0) {
        // Wheel: stateless, forwarded wherever it lands inside.
        if (inside) out.addAll(emit(cb, tCol, tRow));
        return;
      }
      if (wheelOnly) return;

      if (release) {
        final gesture = _gesture;
        if (gesture == null) return;
        _gesture = null;
        out.addAll(
          emit(cb, tCol.clamp(1, limitCol), tRow.clamp(1, limitRow)),
        );
        return;
      }

      final motion = (cb & 0x20) != 0;
      if (motion && (cb & 0x03) == 0x03) {
        // No button is held: authoritative. A gesture still open here lost
        // its release somewhere off-screen — close it out for the child.
        _heal(out);
        if (inside) out.addAll(emit(cb, tCol, tRow));
        return;
      }
      if (motion) {
        // Drag: belongs to whoever owned the press.
        final gesture = _gesture;
        if (gesture == null) return;
        gesture
          ..col = tCol.clamp(1, limitCol)
          ..row = tRow.clamp(1, limitRow);
        out.addAll(emit(cb, gesture.col, gesture.row));
        return;
      }

      // Press. Shift is the host-selection modifier; an outside press is a
      // click on the host's own chrome. Neither belongs to the child — and
      // either way a gesture still open never got its release.
      if ((cb & 0x04) != 0 || !inside) {
        _heal(out);
        return;
      }
      _heal(out);
      _gesture = _Gesture(cb: cb, sgr: sgr, col: tCol, row: tRow);
      out.addAll(emit(cb, tCol, tRow));
    }

    var i = 0;
    while (i < bytes.length) {
      if (i + 2 < bytes.length && bytes[i] == 0x1B && bytes[i + 1] == 0x5B) {
        // SGR mouse: ESC [ < ... M/m
        if (bytes[i + 2] == 0x3C) {
          var j = i + 3;
          var validSgr = true;
          while (j < bytes.length && bytes[j] != 0x4D && bytes[j] != 0x6D) {
            final b = bytes[j];
            if (!((b >= 0x30 && b <= 0x39) || b == 0x3B)) {
              validSgr = false;
              break;
            }
            j++;
          }
          if (validSgr && j < bytes.length) {
            final parts = _sgrParams(bytes, i + 3, j);
            if (parts.length != 3) {
              // Malformed triple — pass through untouched.
              out.addAll(bytes.sublist(i, j + 1));
            } else {
              final terminator = bytes[j];
              routeEvent(
                cb: parts[0],
                col: parts[1],
                row: parts[2],
                release: terminator == 0x6D,
                sgr: true,
                limitCol: maxCol,
                limitRow: maxRow,
                emit: (cb, col, row) =>
                    _encodeSgr(cb, col, row, terminator: terminator),
              );
            }
            i = j + 1;
            continue;
          }
        }
        // X10 mouse: ESC [ M + 3 data bytes. Each field is biased by 0x20,
        // capping coordinates at the 223-cell byte ceiling.
        if (bytes[i + 2] == 0x4D && i + 5 < bytes.length) {
          const ceiling = 223;
          final cb = bytes[i + 3] - 0x20;
          routeEvent(
            cb: cb,
            col: bytes[i + 4] - 0x20,
            row: bytes[i + 5] - 0x20,
            // X10 has no `m`; a release is button 3 with no wheel/motion.
            release: (cb & 0x60) == 0 && (cb & 0x03) == 0x03,
            sgr: false,
            limitCol: maxCol < ceiling ? maxCol : ceiling,
            limitRow: maxRow < ceiling ? maxRow : ceiling,
            emit: _encodeX10,
          );
          i += 6;
          continue;
        }
      }
      out.add(bytes[i]);
      i++;
    }
    return out;
  }

  /// Synthesizes the release a still-open gesture never received, in the
  /// dialect the press arrived in, at the last position the child saw.
  void _heal(List<int> out) {
    final gesture = _gesture;
    if (gesture == null) return;
    _gesture = null;
    final cb = gesture.cb & ~0x20;
    out.addAll(
      gesture.sgr
          ? _encodeSgr(cb, gesture.col, gesture.row, terminator: 0x6D)
          : _encodeX10((cb & ~0x03) | 0x03, gesture.col, gesture.row),
    );
  }

  static List<int> _encodeSgr(
    int cb,
    int col,
    int row, {
    required int terminator,
  }) => [
    0x1B, 0x5B, 0x3C, // ESC [ <
    ...cb.toString().codeUnits,
    0x3B,
    ...col.toString().codeUnits,
    0x3B,
    ...row.toString().codeUnits,
    terminator,
  ];

  static List<int> _encodeX10(int cb, int col, int row) => [
    0x1B, 0x5B, 0x4D, // ESC [ M
    cb + 0x20,
    col + 0x20,
    row + 0x20,
  ];
}

/// Parses the digits-and-semicolons region of an SGR sequence into ints.
List<int> _sgrParams(List<int> bytes, int start, int end) {
  final parts = <int>[];
  var n = 0;
  var hasDigit = false;
  for (var k = start; k < end; k++) {
    final b = bytes[k];
    if (b == 0x3B) {
      parts.add(hasDigit ? n : 0);
      n = 0;
      hasDigit = false;
    } else {
      n = n * 10 + (b - 0x30);
      hasDigit = true;
    }
  }
  if (hasDigit) parts.add(n);
  return parts;
}

MouseEvent? _decodeSgrMouse(List<int> bytes, int paramStart, int terminator) {
  // Parse the digits-and-semicolons region into 3 ints (cb;col;row).
  final parts = _sgrParams(bytes, paramStart, terminator);
  if (parts.length != 3) return null;
  final press = bytes[terminator] == 0x4D;
  return _buildMouseEvent(
    cb: parts[0],
    col: parts[1],
    row: parts[2],
    press: press,
  );
}

MouseEvent _decodeX10Mouse(int cb, int cx, int cy) {
  // X10: each byte is offset by 0x20; col/row are 0x21-based.
  return _buildMouseEvent(
    cb: cb - 0x20,
    col: cx - 0x20,
    row: cy - 0x20,
    press: true,
  );
}

MouseEvent _buildMouseEvent({
  required int cb,
  required int col,
  required int row,
  required bool press,
}) {
  final shift = (cb & 0x04) != 0;
  final alt = (cb & 0x08) != 0;
  final ctrl = (cb & 0x10) != 0;
  final low = cb & 0x03;
  final MouseButton button;
  if ((cb & 0x40) != 0) {
    // Wheel / extended buttons (bit 6).
    button = switch (low) {
      0 => MouseButton.wheelUp,
      1 => MouseButton.wheelDown,
      2 => MouseButton.wheelLeft,
      _ => MouseButton.wheelRight,
    };
  } else {
    button = switch (low) {
      0 => MouseButton.left,
      1 => MouseButton.middle,
      2 => MouseButton.right,
      _ => MouseButton.release,
    };
  }
  return MouseEvent(
    button: button,
    press: press,
    col: col,
    row: row,
    shift: shift,
    alt: alt,
    ctrl: ctrl,
  );
}

/// Decode kitty keyboard protocol sequences to standard VT100
/// with SS3 format for keys that xterm-256color terminfo defines
/// as SS3 (arrows, home, end, F1–F4).
///
/// When the host terminal supports kitty keyboard protocol,
/// keys are encoded differently:
///
/// - `ESC [ codepoint ; modifiers u` — functional/control keys
///   e.g. Ctrl+C = `ESC[99;5u` → decoded to `0x03`
/// - `ESC [ 1 ; modifiers A/B/C/D/H/F` — modified arrows/home/end
///   e.g. arrow up with shift = `ESC[1;2A` → `ESC O A`
/// - `ESC [ A/B/C/D` — plain CSI arrows (from non-kitty terminals)
///   → converted to SS3 format `ESC O A` for terminfo compat
///
/// Single-byte LF (0x0A) is converted to CR (0x0D): some host
/// terminals send LF for Enter when nocterm has raw mode enabled,
/// but the child PTY expects CR (the TTY's ICRNL flag converts
/// CR→LF, not the other way around).
///
/// Non-kitty bytes otherwise pass through unchanged.
List<int> decodeKittySequence(List<int> bytes) {
  // LF → CR: host terminal may send 0x0A for Enter.
  if (bytes.length == 1 && bytes[0] == 0x0A) return const [0x0D];

  if (bytes.length < 3 || bytes[0] != 0x1B || bytes[1] != 0x5B) {
    return bytes;
  }

  // Plain CSI arrow/home/end/F1-F4 (3 bytes): ESC [ A/B/C/D/H/F/P/Q/R/S
  // Convert to SS3 format for xterm-256color terminfo compat.
  if (bytes.length == 3 && _isSS3Final(bytes[2])) {
    return [0x1B, 0x4F, bytes[2]];
  }

  if (bytes.length < 4) return bytes;

  // Kitty CSI u format: ESC [ codepoint ; modifiers u
  final last = bytes.last;
  if (last == 0x75) {
    // 'u' terminator
    final paramStr = String.fromCharCodes(bytes.sublist(2, bytes.length - 1));
    final parts = paramStr.split(';');
    if (parts.isEmpty) return bytes;
    final codepoint = int.tryParse(parts[0].split(':').first);
    if (codepoint == null) return bytes;
    final modParts = parts.length > 1 ? parts[1].split(':') : const <String>[];
    final modifier = modParts.isNotEmpty ? int.tryParse(modParts[0]) ?? 1 : 1;
    final eventType = modParts.length > 1 ? int.tryParse(modParts[1]) ?? 1 : 1;

    // Drop release events (event type 3) — PTYs only care about press/repeat.
    if (eventType == 3) return const [];

    // Kitty modifier bitmask (subtract 1 from param value):
    // bit 0 = shift, bit 1 = alt, bit 2 = ctrl, bit 3 = super
    final bits = modifier - 1;
    final shift = bits & 1 != 0;
    final alt = bits & 2 != 0;
    final ctrl = bits & 4 != 0;

    // Shift+Tab → ESC[Z (back-tab per xterm-256color terminfo)
    if (shift && codepoint == 9) return [0x1B, 0x5B, 0x5A];

    if (ctrl && codepoint >= 0x61 && codepoint <= 0x7A) {
      // Ctrl + lowercase letter → control byte
      return [codepoint - 0x60];
    }
    if (ctrl && codepoint >= 0x41 && codepoint <= 0x5A) {
      // Ctrl + uppercase letter → control byte
      return [codepoint - 0x40];
    }
    // Alt + key → ESC prefix (standard terminal Alt encoding)
    if (alt) return [0x1B, codepoint];
    // Non-modified: emit the codepoint as UTF-8
    return [codepoint];
  }

  // Modified arrow/home/end/F1-F4: ESC [ 1 ; modifiers A/B/C/D/H/F/P/Q/R/S
  // xterm-256color terminfo defines these as SS3 (ESC O <final>),
  // so programs like less/vim expect SS3 format, not CSI format.
  if (_isSS3Final(last)) {
    return [0x1B, 0x4F, last]; // ESC O <final>
  }

  return bytes;
}

/// Whether [byte] is a CSI final that xterm-256color terminfo
/// defines as SS3 (ESC O).
///
/// Arrows A/B/C/D, Home H, End F, F1-F4 P/Q/R/S.
bool _isSS3Final(int byte) =>
    byte == 0x41 || // A — up
    byte == 0x42 || // B — down
    byte == 0x43 || // C — right
    byte == 0x44 || // D — left
    byte == 0x48 || // H — home
    byte == 0x46 || // F — end
    byte == 0x50 || // P — F1
    byte == 0x51 || // Q — F2
    byte == 0x52 || // R — F3
    byte == 0x53; //   S — F4
