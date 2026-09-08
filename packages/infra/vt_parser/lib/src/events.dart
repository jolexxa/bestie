import 'package:meta/meta.dart';

/// A structured event emitted by the VT500 state machine.
///
/// The `ParserEvent` hierarchy is `sealed` so callers can exhaustively
/// pattern-match over it. Events are immutable and safe to retain.
@immutable
sealed class ParserEvent {
  const ParserEvent();
}

/// A printable character was decoded (post-UTF-8).
final class PrintEvent extends ParserEvent {
  /// Create a [PrintEvent] for the given Unicode code point.
  const PrintEvent(this.char);

  /// Unicode code point.
  final int char;

  @override
  bool operator ==(Object other) => other is PrintEvent && other.char == char;

  @override
  int get hashCode => Object.hash(PrintEvent, char);

  @override
  String toString() {
    final hex = char.toRadixString(16).padLeft(4, '0');
    return 'PrintEvent(U+$hex)';
  }
}

/// A C0 (0x00..0x1F) or C1 (0x80..0x9F) control byte was received.
final class ExecuteEvent extends ParserEvent {
  /// Create an [ExecuteEvent] for the given control byte.
  const ExecuteEvent(this.byte);

  /// The control byte.
  final int byte;

  @override
  bool operator ==(Object other) => other is ExecuteEvent && other.byte == byte;

  @override
  int get hashCode => Object.hash(ExecuteEvent, byte);

  @override
  String toString() =>
      'ExecuteEvent(0x${byte.toRadixString(16).padLeft(2, '0')})';
}

/// A simple ESC + final-byte sequence (no CSI, possibly with
/// intermediates). Examples: ESC 7, ESC 8, ESC D, ESC E, ESC M,
/// ESC ( B (charset designation).
final class EscDispatchEvent extends ParserEvent {
  /// Create an [EscDispatchEvent].
  const EscDispatchEvent({
    required this.intermediates,
    required this.finalByte,
    required this.ignore,
  });

  /// Any intermediate bytes collected between ESC and the final
  /// byte (0x20..0x2F range).
  final List<int> intermediates;

  /// The final byte that terminated the sequence.
  final int finalByte;

  /// `true` if intermediate overflow caused bytes to be dropped.
  final bool ignore;

  @override
  bool operator ==(Object other) =>
      other is EscDispatchEvent &&
      other.finalByte == finalByte &&
      other.ignore == ignore &&
      _listEq(other.intermediates, intermediates);

  @override
  int get hashCode => Object.hash(
    EscDispatchEvent,
    finalByte,
    ignore,
    Object.hashAll(intermediates),
  );

  @override
  String toString() {
    final ch = String.fromCharCode(finalByte);
    return 'EscDispatchEvent(intermediates=$intermediates, '
        "finalByte='$ch', ignore=$ignore)";
  }
}

/// A complete CSI sequence (`ESC [ ... final`).
final class CsiDispatchEvent extends ParserEvent {
  /// Create a [CsiDispatchEvent].
  const CsiDispatchEvent({
    required this.params,
    required this.intermediates,
    required this.finalByte,
    required this.ignore,
  });

  /// Parameter groups. Each outer entry is one top-level parameter;
  /// the inner list holds its subparameters (`:`-separated).
  ///
  /// A bare `CSI 1;2m` parses to `[[1], [2]]`. An extended color
  /// `CSI 38:2:255:0:0m` parses to `[[38, 2, 255, 0, 0]]`.
  final List<List<int>> params;

  /// Intermediate bytes collected between `[` and the final byte.
  final List<int> intermediates;

  /// The final byte that terminated the sequence.
  final int finalByte;

  /// `true` if parameter or intermediate overflow caused bytes to
  /// be dropped.
  final bool ignore;

  @override
  bool operator ==(Object other) =>
      other is CsiDispatchEvent &&
      other.finalByte == finalByte &&
      other.ignore == ignore &&
      _listEq(other.intermediates, intermediates) &&
      _nestedListEq(other.params, params);

  @override
  int get hashCode => Object.hash(
    CsiDispatchEvent,
    finalByte,
    ignore,
    Object.hashAll(intermediates),
    Object.hashAll(params.map(Object.hashAll)),
  );

  @override
  String toString() {
    final ch = String.fromCharCode(finalByte);
    return 'CsiDispatchEvent(params=$params, '
        'intermediates=$intermediates, '
        "finalByte='$ch', ignore=$ignore)";
  }
}

/// A complete OSC sequence (`ESC ]` ... BEL or ST).
final class OscDispatchEvent extends ParserEvent {
  /// Create an [OscDispatchEvent].
  const OscDispatchEvent({
    required this.params,
    required this.bellTerminated,
  });

  /// Raw bytes of each `;`-separated parameter. We emit bytes rather
  /// than strings because OSC payloads are not required to be UTF-8
  /// (hyperlink targets, file paths, palette queries, …).
  final List<List<int>> params;

  /// `true` if the sequence was terminated by BEL (`0x07`), `false`
  /// if it was terminated by ST (`ESC \`).
  final bool bellTerminated;

  @override
  bool operator ==(Object other) =>
      other is OscDispatchEvent &&
      other.bellTerminated == bellTerminated &&
      _nestedListEq(other.params, params);

  @override
  int get hashCode => Object.hash(
    OscDispatchEvent,
    bellTerminated,
    Object.hashAll(params.map(Object.hashAll)),
  );

  @override
  String toString() =>
      'OscDispatchEvent(params=$params, bellTerminated=$bellTerminated)';
}

/// A DCS payload is about to start. Expect a sequence of
/// [DcsPutEvent]s followed by a [DcsUnhookEvent].
final class DcsHookEvent extends ParserEvent {
  /// Create a [DcsHookEvent].
  const DcsHookEvent({
    required this.params,
    required this.intermediates,
    required this.finalByte,
    required this.ignore,
  });

  /// Parameter groups, identical in shape to [CsiDispatchEvent.params].
  final List<List<int>> params;

  /// Intermediate bytes between `P` and the final byte.
  final List<int> intermediates;

  /// The final byte that selected the DCS handler.
  final int finalByte;

  /// `true` if parameter or intermediate overflow forced the parser
  /// to discard bytes.
  final bool ignore;

  @override
  bool operator ==(Object other) =>
      other is DcsHookEvent &&
      other.finalByte == finalByte &&
      other.ignore == ignore &&
      _listEq(other.intermediates, intermediates) &&
      _nestedListEq(other.params, params);

  @override
  int get hashCode => Object.hash(
    DcsHookEvent,
    finalByte,
    ignore,
    Object.hashAll(intermediates),
    Object.hashAll(params.map(Object.hashAll)),
  );

  @override
  String toString() {
    final ch = String.fromCharCode(finalByte);
    return 'DcsHookEvent(params=$params, '
        'intermediates=$intermediates, '
        "finalByte='$ch', ignore=$ignore)";
  }
}

/// A single byte of DCS payload between hook and unhook.
final class DcsPutEvent extends ParserEvent {
  /// Create a [DcsPutEvent] for the given payload byte.
  const DcsPutEvent(this.byte);

  /// The payload byte.
  final int byte;

  @override
  bool operator ==(Object other) => other is DcsPutEvent && other.byte == byte;

  @override
  int get hashCode => Object.hash(DcsPutEvent, byte);

  @override
  String toString() =>
      'DcsPutEvent(0x${byte.toRadixString(16).padLeft(2, '0')})';
}

/// The DCS payload is complete.
final class DcsUnhookEvent extends ParserEvent {
  /// Create a [DcsUnhookEvent].
  const DcsUnhookEvent();

  @override
  bool operator ==(Object other) => other is DcsUnhookEvent;

  @override
  int get hashCode => (DcsUnhookEvent).hashCode;

  @override
  String toString() => 'DcsUnhookEvent()';
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _nestedListEq(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_listEq(a[i], b[i])) return false;
  }
  return true;
}
