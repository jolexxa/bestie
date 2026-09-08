// State machine and dispatch logic ported from alacritty/vte's
// `src/lib.rs`. Upstream copyright (c) 2016 Joe Wilm; original
// license MIT / Apache-2.0. See ../../THIRD_PARTY_NOTICES.md.
import 'dart:async';
import 'dart:typed_data';

import 'package:vt_parser/src/constants.dart';
import 'package:vt_parser/src/events.dart';
import 'package:vt_parser/src/params.dart';
import 'package:vt_parser/src/sink.dart';
import 'package:vt_parser/src/state.dart';

/// Paul Williams VT500 state machine parser.
///
/// Consume a byte stream from a PTY via [advance] and receive
/// structured [ParserEvent]s either through the [events] broadcast
/// stream or through an optional [ParserSink] passed to the
/// constructor. Both fire simultaneously if both are in use.
///
/// The implementation is a straight port of
/// `alacritty/vte`'s `src/lib.rs`, with Dart idioms for UTF-8
/// handling, sealed events, and stream-based dispatch. The state
/// transitions match Paul Williams' diagram at
/// <https://vt100.net/emu/dec_ansi_parser> byte-for-byte.
class VtParser {
  /// Create a parser. Pass [sink] to receive events via a
  /// callback interface in addition to the [events] stream.
  VtParser({ParserSink? sink}) : _sink = sink;

  final ParserSink? _sink;

  // sync: true so events fire synchronously during `advance()` —
  // tests and downstream screen models both rely on this.
  // ignore_for_file: avoid_redundant_argument_values
  final StreamController<ParserEvent> _controller =
      StreamController<ParserEvent>.broadcast(sync: true);

  /// Broadcast stream of [ParserEvent]s. Events fire synchronously
  /// during [advance]; any listener added before `advance` runs will
  /// receive them.
  Stream<ParserEvent> get events => _controller.stream;

  // --- State machine state ---------------------------------------------------

  ParserState _state = ParserState.ground;
  final Uint8List _intermediates = Uint8List(maxIntermediates);
  int _intermediateIdx = 0;
  final Params _params = Params();
  int _param = 0;
  bool _ignoring = false;

  // OSC collection.
  final List<int> _oscRaw = <int>[];
  final List<(int, int)> _oscParams = List<(int, int)>.filled(maxOscParams, (
    0,
    0,
  ), growable: false);
  int _oscNumParams = 0;

  // Partial UTF-8 state. A validated lead byte plus up to three
  // continuation bytes that we've seen but can't yet decode into a
  // full code point because the input buffer ran out.
  final Uint8List _partialUtf8 = Uint8List(4);
  int _partialUtf8Len = 0;

  /// Reset the parser to the ground state and drop any in-progress
  /// sequence. Called externally by consumers that want to discard
  /// partial input (e.g. after RIS or session restart).
  void reset() {
    _state = ParserState.ground;
    _intermediateIdx = 0;
    _params.clear();
    _param = 0;
    _ignoring = false;
    _oscRaw.clear();
    _oscNumParams = 0;
    _partialUtf8Len = 0;
  }

  /// Feed a chunk of bytes into the parser. Incomplete sequences
  /// (partial UTF-8 or unterminated CSI/OSC/DCS) are retained in
  /// internal state and resumed on the next call.
  void advance(List<int> bytes) {
    if (bytes.isEmpty) return;
    var i = 0;

    if (_partialUtf8Len != 0) {
      i += _advancePartialUtf8(bytes);
    }

    while (i != bytes.length) {
      if (_state == ParserState.ground) {
        i += _advanceGround(bytes, i);
      } else {
        final byte = bytes[i];
        _changeState(byte);
        i += 1;
      }
    }
  }

  // --- State dispatch --------------------------------------------------------

  // `advance` never calls this when `_state == ground`, so the
  // switch below does not need a `ground` case. We use an
  // if-else chain rather than a Dart switch so the coverage tool
  // doesn't try to count an unreachable case label.
  void _changeState(int byte) {
    final state = _state;
    if (state == ParserState.csiEntry) {
      _advanceCsiEntry(byte);
    } else if (state == ParserState.csiIgnore) {
      _advanceCsiIgnore(byte);
    } else if (state == ParserState.csiIntermediate) {
      _advanceCsiIntermediate(byte);
    } else if (state == ParserState.csiParam) {
      _advanceCsiParam(byte);
    } else if (state == ParserState.dcsEntry) {
      _advanceDcsEntry(byte);
    } else if (state == ParserState.dcsIgnore) {
      _anywhere(byte);
    } else if (state == ParserState.dcsIntermediate) {
      _advanceDcsIntermediate(byte);
    } else if (state == ParserState.dcsParam) {
      _advanceDcsParam(byte);
    } else if (state == ParserState.dcsPassthrough) {
      _advanceDcsPassthrough(byte);
    } else if (state == ParserState.escape) {
      _advanceEsc(byte);
    } else if (state == ParserState.escapeIntermediate) {
      _advanceEscIntermediate(byte);
    } else if (state == ParserState.oscString) {
      _advanceOscString(byte);
    } else if (state == ParserState.sosPmApcString) {
      _anywhere(byte);
    }
  }

  // CSI entry: ESC [ has been consumed; nothing collected yet.
  void _advanceCsiEntry(int byte) {
    if (_isC0Control(byte)) {
      _execute(byte);
    } else if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
      _state = ParserState.csiIntermediate;
    } else if (byte >= 0x30 && byte <= 0x39) {
      _actionParamNext(byte);
      _state = ParserState.csiParam;
    } else if (byte == 0x3A) {
      _actionSubparam();
      _state = ParserState.csiParam;
    } else if (byte == 0x3B) {
      _actionParam();
      _state = ParserState.csiParam;
    } else if (byte >= 0x3C && byte <= 0x3F) {
      _actionCollect(byte);
      _state = ParserState.csiParam;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      _actionCsiDispatch(byte);
    } else {
      _anywhere(byte);
    }
  }

  void _advanceCsiIgnore(int byte) {
    if (_isC0Control(byte)) {
      _execute(byte);
    } else if (byte >= 0x20 && byte <= 0x3F) {
      // swallow
    } else if (byte >= 0x40 && byte <= 0x7E) {
      _state = ParserState.ground;
    } else if (byte == 0x7F) {
      // swallow
    } else {
      _anywhere(byte);
    }
  }

  void _advanceCsiIntermediate(int byte) {
    if (_isC0Control(byte)) {
      _execute(byte);
    } else if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
    } else if (byte >= 0x30 && byte <= 0x3F) {
      _state = ParserState.csiIgnore;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      _actionCsiDispatch(byte);
    } else {
      _anywhere(byte);
    }
  }

  void _advanceCsiParam(int byte) {
    if (_isC0Control(byte)) {
      _execute(byte);
    } else if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
      _state = ParserState.csiIntermediate;
    } else if (byte >= 0x30 && byte <= 0x39) {
      _actionParamNext(byte);
    } else if (byte == 0x3A) {
      _actionSubparam();
    } else if (byte == 0x3B) {
      _actionParam();
    } else if (byte >= 0x3C && byte <= 0x3F) {
      _state = ParserState.csiIgnore;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      _actionCsiDispatch(byte);
    } else if (byte == 0x7F) {
      // swallow
    } else {
      _anywhere(byte);
    }
  }

  void _advanceDcsEntry(int byte) {
    if (_isC0Control(byte)) {
      // silently swallowed in DCS entry
    } else if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
      _state = ParserState.dcsIntermediate;
    } else if (byte >= 0x30 && byte <= 0x39) {
      _actionParamNext(byte);
      _state = ParserState.dcsParam;
    } else if (byte == 0x3A) {
      _actionSubparam();
      _state = ParserState.dcsParam;
    } else if (byte == 0x3B) {
      _actionParam();
      _state = ParserState.dcsParam;
    } else if (byte >= 0x3C && byte <= 0x3F) {
      _actionCollect(byte);
      _state = ParserState.dcsParam;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      _actionHook(byte);
    } else if (byte == 0x7F) {
      // swallow
    } else {
      _anywhere(byte);
    }
  }

  void _advanceDcsIntermediate(int byte) {
    if (_isC0Control(byte)) {
      // swallow
    } else if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
    } else if (byte >= 0x30 && byte <= 0x3F) {
      _state = ParserState.dcsIgnore;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      _actionHook(byte);
    } else if (byte == 0x7F) {
      // swallow
    } else {
      _anywhere(byte);
    }
  }

  void _advanceDcsParam(int byte) {
    if (_isC0Control(byte)) {
      // swallow
    } else if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
      _state = ParserState.dcsIntermediate;
    } else if (byte >= 0x30 && byte <= 0x39) {
      _actionParamNext(byte);
    } else if (byte == 0x3A) {
      _actionSubparam();
    } else if (byte == 0x3B) {
      _actionParam();
    } else if (byte >= 0x3C && byte <= 0x3F) {
      _state = ParserState.dcsIgnore;
    } else if (byte >= 0x40 && byte <= 0x7E) {
      _actionHook(byte);
    } else if (byte == 0x7F) {
      // swallow
    } else {
      _anywhere(byte);
    }
  }

  void _advanceDcsPassthrough(int byte) {
    if ((byte >= 0x00 && byte <= 0x17) ||
        byte == 0x19 ||
        (byte >= 0x1C && byte <= 0x7E)) {
      _dcsPut(byte);
    } else if (byte == 0x18 || byte == 0x1A) {
      _dcsUnhook();
      _execute(byte);
      _state = ParserState.ground;
    } else if (byte == 0x1B) {
      _dcsUnhook();
      _resetParams();
      _state = ParserState.escape;
    } else if (byte == 0x7F) {
      // swallow
    } else if (byte == 0x9C) {
      _dcsUnhook();
      _state = ParserState.ground;
    }
    // Anything else (including 0x80..0x9B, 0x9D..0xFF) is silently
    // dropped inside DCS passthrough, matching vte.
  }

  void _advanceEsc(int byte) {
    // C0 controls: execute and stay in escape.
    if (_isC0Control(byte)) {
      _execute(byte);
      return;
    }
    // CAN / SUB: abort escape, execute, go to ground.
    if (byte == 0x18 || byte == 0x1A) {
      _execute(byte);
      _state = ParserState.ground;
      return;
    }
    // ESC again: stay in escape, reset.
    if (byte == 0x1B) {
      _resetParams();
      return;
    }
    if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
      _state = ParserState.escapeIntermediate;
      return;
    }
    if (byte >= 0x30 && byte <= 0x4F) {
      _actionEscDispatch(byte);
      _state = ParserState.ground;
      return;
    }
    if (byte == 0x50) {
      _resetParams();
      _state = ParserState.dcsEntry;
      return;
    }
    if (byte >= 0x51 && byte <= 0x57) {
      _actionEscDispatch(byte);
      _state = ParserState.ground;
      return;
    }
    if (byte == 0x58) {
      _state = ParserState.sosPmApcString;
      return;
    }
    if (byte >= 0x59 && byte <= 0x5A) {
      _actionEscDispatch(byte);
      _state = ParserState.ground;
      return;
    }
    if (byte == 0x5B) {
      _resetParams();
      _state = ParserState.csiEntry;
      return;
    }
    if (byte == 0x5C) {
      _actionEscDispatch(byte);
      _state = ParserState.ground;
      return;
    }
    if (byte == 0x5D) {
      _oscRaw.clear();
      _oscNumParams = 0;
      _state = ParserState.oscString;
      return;
    }
    if (byte >= 0x5E && byte <= 0x5F) {
      _state = ParserState.sosPmApcString;
      return;
    }
    if (byte >= 0x60 && byte <= 0x7E) {
      _actionEscDispatch(byte);
      _state = ParserState.ground;
      return;
    }
    // Fallthrough (e.g. DEL 0x7F, 0x80..0xFF): swallow.
  }

  void _advanceEscIntermediate(int byte) {
    if (_isC0Control(byte)) {
      _execute(byte);
    } else if (byte >= 0x20 && byte <= 0x2F) {
      _actionCollect(byte);
    } else if (byte >= 0x30 && byte <= 0x7E) {
      _actionEscDispatch(byte);
      _state = ParserState.ground;
    } else if (byte == 0x7F) {
      // swallow
    } else {
      _anywhere(byte);
    }
  }

  void _advanceOscString(int byte) {
    if (byte == 0x07) {
      _oscEnd(bellTerminated: true);
      _state = ParserState.ground;
    } else if (byte == 0x18 || byte == 0x1A) {
      _oscEnd(bellTerminated: false);
      _execute(byte);
      _state = ParserState.ground;
    } else if (byte == 0x1B) {
      _oscEnd(bellTerminated: false);
      _resetParams();
      _state = ParserState.escape;
    } else if ((byte >= 0x00 && byte <= 0x06) ||
        (byte >= 0x08 && byte <= 0x17) ||
        byte == 0x19 ||
        (byte >= 0x1C && byte <= 0x1F)) {
      // C0 controls other than BEL/CAN/SUB/ESC are silently swallowed.
    } else if (byte == 0x3B) {
      _actionOscPutParam();
    } else {
      _actionOscPut(byte);
    }
  }

  // "Anywhere" transition from vte: CAN, SUB, ESC can interrupt any
  // state and send us back to ground (or escape). Used for DcsIgnore,
  // SosPmApcString, and as a fallback.
  void _anywhere(int byte) {
    if (byte == 0x18 || byte == 0x1A) {
      _execute(byte);
      _state = ParserState.ground;
    } else if (byte == 0x1B) {
      _resetParams();
      _state = ParserState.escape;
    }
    // Everything else is swallowed.
  }

  // --- Ground state + UTF-8 --------------------------------------------------

  /// Advance from the ground state. Returns the number of bytes
  /// consumed from [bytes] starting at [start]. Handles print,
  /// execute, UTF-8 decoding, and ESC transition.
  int _advanceGround(List<int> bytes, int start) {
    var i = start;
    while (i < bytes.length) {
      final b = bytes[i];

      // Fast path: ASCII printable or single-byte controls.
      if (b < 0x80) {
        if (b == 0x1B) {
          _resetParams();
          _state = ParserState.escape;
          return (i - start) + 1;
        }
        if (b < 0x20 || b == 0x7F) {
          _execute(b);
        } else {
          _print(b);
        }
        i += 1;
        continue;
      }

      // 8-bit C1 controls (0x80..0x9F) are dispatched as Execute, but
      // they are valid UTF-8 continuation bytes too. We detect them
      // by treating any byte without a valid lead-byte length as a
      // potential C1 if it's in that range, matching vte's behavior
      // for invalid utf8 where a single byte <= 0x9F is executed.
      final need = _utf8LeadLen(b);
      if (need < 0) {
        if (b <= 0x9F) {
          _execute(b);
        } else {
          _printCodePoint(0xFFFD);
        }
        i += 1;
        continue;
      }

      if (i + need > bytes.length) {
        // Not enough bytes for this codepoint; save the tail to the
        // partial buffer and stop.
        final saved = bytes.length - i;
        for (var k = 0; k < saved; k++) {
          _partialUtf8[k] = bytes[i + k];
        }
        _partialUtf8Len = saved;
        return bytes.length - start;
      }

      final cp = _utf8Decode(bytes, i, need);
      if (cp < 0) {
        _printCodePoint(0xFFFD);
        i += 1;
        continue;
      }
      if (cp >= 0x80 && cp <= 0x9F) {
        _execute(cp);
      } else {
        _printCodePoint(cp);
      }
      i += need;
    }
    return i - start;
  }

  /// Try to complete a partial UTF-8 codepoint begun on a previous
  /// call. Returns the number of bytes consumed from [bytes].
  int _advancePartialUtf8(List<int> bytes) {
    final lead = _partialUtf8[0];
    // We only ever save a validated lead byte into the partial
    // buffer (see `_advanceGround`), so `_utf8LeadLen` is
    // guaranteed to return a length >= 2 here.
    final need = _utf8LeadLen(lead);
    assert(need >= 2, 'partial buffer must hold a valid lead');

    final remaining = need - _partialUtf8Len;
    if (bytes.length < remaining) {
      for (var k = 0; k < bytes.length; k++) {
        _partialUtf8[_partialUtf8Len + k] = bytes[k];
      }
      _partialUtf8Len += bytes.length;
      return bytes.length;
    }

    for (var k = 0; k < remaining; k++) {
      _partialUtf8[_partialUtf8Len + k] = bytes[k];
    }
    final cp = _utf8Decode(_partialUtf8, 0, need);
    _partialUtf8Len = 0;
    if (cp < 0) {
      _printCodePoint(0xFFFD);
    } else if (cp >= 0x80 && cp <= 0x9F) {
      _execute(cp);
    } else {
      _printCodePoint(cp);
    }
    return remaining;
  }

  // --- Actions ---------------------------------------------------------------

  void _actionCollect(int byte) {
    if (_intermediateIdx == maxIntermediates) {
      _ignoring = true;
    } else {
      _intermediates[_intermediateIdx] = byte;
      _intermediateIdx += 1;
    }
  }

  void _actionSubparam() {
    if (_params.isFull) {
      _ignoring = true;
    } else {
      _params.extend(_param);
      _param = 0;
    }
  }

  void _actionParam() {
    if (_params.isFull) {
      _ignoring = true;
    } else {
      _params.push(_param);
      _param = 0;
    }
  }

  void _actionParamNext(int byte) {
    if (_params.isFull) {
      _ignoring = true;
    } else {
      // Saturating mul/add to u16 to match vte.
      var value = _param * 10 + (byte - 0x30);
      if (value > 0xFFFF) value = 0xFFFF;
      _param = value;
    }
  }

  void _actionOscPut(int byte) {
    if (_oscRaw.length >= maxOscRaw) return;
    _oscRaw.add(byte);
  }

  void _actionOscPutParam() {
    final idx = _oscRaw.length;
    final p = _oscNumParams;
    if (p == 0) {
      _oscParams[0] = (0, idx);
    } else if (p == maxOscParams) {
      return;
    } else {
      final prev = _oscParams[p - 1];
      _oscParams[p] = (prev.$2, idx);
    }
    _oscNumParams += 1;
  }

  void _actionCsiDispatch(int byte) {
    if (_params.isFull) {
      _ignoring = true;
    } else {
      _params.push(_param);
    }
    final params = _params.toList();
    final intermediates = _intermediates.sublist(0, _intermediateIdx);
    final ignore = _ignoring;
    _emit(
      CsiDispatchEvent(
        params: params,
        intermediates: intermediates,
        finalByte: byte,
        ignore: ignore,
      ),
    );
    _sink?.onCsiDispatch(
      params: params,
      intermediates: intermediates,
      finalByte: byte,
      ignore: ignore,
    );
    _state = ParserState.ground;
  }

  void _actionEscDispatch(int byte) {
    final intermediates = _intermediates.sublist(0, _intermediateIdx);
    final ignore = _ignoring;
    _emit(
      EscDispatchEvent(
        intermediates: intermediates,
        finalByte: byte,
        ignore: ignore,
      ),
    );
    _sink?.onEscDispatch(
      intermediates: intermediates,
      finalByte: byte,
      ignore: ignore,
    );
  }

  void _actionHook(int byte) {
    if (_params.isFull) {
      _ignoring = true;
    } else {
      _params.push(_param);
    }
    final params = _params.toList();
    final intermediates = _intermediates.sublist(0, _intermediateIdx);
    final ignore = _ignoring;
    _emit(
      DcsHookEvent(
        params: params,
        intermediates: intermediates,
        finalByte: byte,
        ignore: ignore,
      ),
    );
    _sink?.onDcsHook(
      params: params,
      intermediates: intermediates,
      finalByte: byte,
      ignore: ignore,
    );
    _state = ParserState.dcsPassthrough;
  }

  void _oscEnd({required bool bellTerminated}) {
    _actionOscPutParam();
    final params = <List<int>>[];
    for (var i = 0; i < _oscNumParams; i++) {
      final (start, end) = _oscParams[i];
      params.add(_oscRaw.sublist(start, end));
    }
    _emit(OscDispatchEvent(params: params, bellTerminated: bellTerminated));
    _sink?.onOscDispatch(params: params, bellTerminated: bellTerminated);
    _oscRaw.clear();
    _oscNumParams = 0;
  }

  void _resetParams() {
    _intermediateIdx = 0;
    _ignoring = false;
    _param = 0;
    _params.clear();
  }

  // --- Emit helpers ----------------------------------------------------------

  void _print(int byte) {
    _emit(PrintEvent(byte));
    _sink?.onPrint(byte);
  }

  void _printCodePoint(int cp) {
    _emit(PrintEvent(cp));
    _sink?.onPrint(cp);
  }

  void _execute(int byte) {
    _emit(ExecuteEvent(byte));
    _sink?.onExecute(byte);
  }

  void _dcsPut(int byte) {
    _emit(DcsPutEvent(byte));
    _sink?.onDcsPut(byte);
  }

  void _dcsUnhook() {
    _emit(const DcsUnhookEvent());
    _sink?.onDcsUnhook();
  }

  void _emit(ParserEvent event) {
    if (_controller.hasListener) {
      _controller.add(event);
    }
  }

  // --- Byte predicates / UTF-8 helpers ---------------------------------------

  static bool _isC0Control(int byte) {
    // 0x00..0x17, 0x19, 0x1C..0x1F — matches vte's range for "execute
    // within structured states". 0x18 (CAN), 0x1A (SUB), 0x1B (ESC)
    // are handled specially by the anywhere transition.
    if (byte <= 0x17) return true;
    if (byte == 0x19) return true;
    if (byte >= 0x1C && byte <= 0x1F) return true;
    return false;
  }

  /// Expected total length (in bytes) of a UTF-8 sequence whose
  /// first byte is [b]. Returns `-1` for an invalid lead.
  static int _utf8LeadLen(int b) {
    if (b < 0x80) return 1;
    if (b < 0xC2) return -1;
    if (b < 0xE0) return 2;
    if (b < 0xF0) return 3;
    if (b < 0xF5) return 4;
    return -1;
  }

  /// Decode [n] UTF-8 bytes starting at `bytes[start]`. Caller must
  /// ensure `n` is 2, 3, or 4 — single-byte ASCII is handled along
  /// the fast path in [_advanceGround] and never reaches here.
  /// Returns the code point on success or `-1` if the continuation
  /// bytes are invalid / overlong / encode a surrogate.
  static int _utf8Decode(List<int> bytes, int start, int n) {
    assert(n >= 2 && n <= 4, '_utf8Decode requires n in 2..4, got $n');
    if (n == 2) {
      final b1 = bytes[start + 1];
      if ((b1 & 0xC0) != 0x80) return -1;
      return ((bytes[start] & 0x1F) << 6) | (b1 & 0x3F);
    }
    if (n == 3) {
      final b0 = bytes[start];
      final b1 = bytes[start + 1];
      final b2 = bytes[start + 2];
      if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80) return -1;
      if (b0 == 0xE0 && b1 < 0xA0) return -1; // overlong
      if (b0 == 0xED && b1 >= 0xA0) return -1; // surrogate range
      return ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F);
    }
    // n == 4
    final b0 = bytes[start];
    final b1 = bytes[start + 1];
    final b2 = bytes[start + 2];
    final b3 = bytes[start + 3];
    if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) {
      return -1;
    }
    if (b0 == 0xF0 && b1 < 0x90) return -1; // overlong
    if (b0 == 0xF4 && b1 >= 0x90) return -1; // > U+10FFFF
    return ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F);
  }
}
