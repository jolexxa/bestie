import 'dart:convert';

/// Encoders for the replies that `Screen` sends back to the child
/// process when it asks for device attributes, status, cursor
/// position, or palette information.
///
/// Each helper returns a `List<int>` of UTF-8 bytes ready to be
/// written to the outbound sink. Separating encoding from sending
/// makes the replies easy to unit-test without plumbing a real
/// sink.
abstract final class OutboundEncoder {
  /// `CSI ? 62 ; 22 c` — DA1 response, "VT220 with ANSI color +
  /// selective erase" (xterm's common profile).
  static List<int> da1() => utf8.encode('\x1B[?62;22c');

  /// `CSI > 0 ; 0 ; 0 c` — DA2 response, safe identity.
  static List<int> da2() => utf8.encode('\x1B[>0;0;0c');

  /// `ESC P ! | 00000000 ESC \` — DA3 response (DECRPTUI).
  static List<int> da3() => utf8.encode('\x1BP!|00000000\x1B\\');

  /// `CSI 0 n` — DSR status: "terminal OK".
  static List<int> dsrOk() => utf8.encode('\x1B[0n');

  /// `CSI row ; col R` — cursor position report.
  static List<int> cpr(int row, int col) => utf8.encode('\x1B[$row;${col}R');

  /// `CSI ? row ; col ; 0 R` — DECXCPR response.
  static List<int> dexCpr(int row, int col) =>
      utf8.encode('\x1B[?$row;$col;0R');

  /// `OSC 4 ; index ; rgb:rr/gg/bb ST` — palette query reply. We
  /// return the standard 16-color xterm palette values for
  /// indices 0..15. Indices outside that range return `null` and
  /// the caller drops the query.
  static List<int>? palette(int index) {
    if (index < 0 || index > 15) return null;
    final (r, g, b) = _defaultPalette[index];
    final rr = r.toRadixString(16).padLeft(2, '0');
    final gg = g.toRadixString(16).padLeft(2, '0');
    final bb = b.toRadixString(16).padLeft(2, '0');
    return utf8.encode('\x1B]4;$index;rgb:$rr$rr/$gg$gg/$bb$bb\x1B\\');
  }

  /// `OSC 10 ; rgb:cc/cc/cc ST` — default foreground query reply.
  static List<int> defaultForeground() =>
      utf8.encode('\x1B]10;rgb:cccc/cccc/cccc\x1B\\');

  /// `OSC 11 ; rgb:00/00/00 ST` — default background query reply.
  static List<int> defaultBackground() =>
      utf8.encode('\x1B]11;rgb:0000/0000/0000\x1B\\');
}

/// Canonical xterm 16-color palette.
const List<(int, int, int)> _defaultPalette = [
  (0, 0, 0), // black
  (205, 0, 0), // red
  (0, 205, 0), // green
  (205, 205, 0), // yellow
  (0, 0, 238), // blue
  (205, 0, 205), // magenta
  (0, 205, 205), // cyan
  (229, 229, 229), // white
  (127, 127, 127), // bright black
  (255, 0, 0), // bright red
  (0, 255, 0), // bright green
  (255, 255, 0), // bright yellow
  (92, 92, 255), // bright blue
  (255, 0, 255), // bright magenta
  (0, 255, 255), // bright cyan
  (255, 255, 255), // bright white
];
