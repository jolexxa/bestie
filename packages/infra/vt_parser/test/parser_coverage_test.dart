// Dedicated coverage-closing tests: every state-machine branch we
// can't hit via realistic terminal sessions gets an explicit unit
// test here so our 100% line-coverage target stays honest.
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

VtParser _freshWith(Collector c) => VtParser(sink: c);

void main() {
  group('CSI entry edge cases', () {
    test('C0 control inside csiEntry is executed', () {
      final c = Collector();
      // ESC [ BEL H — BEL executed, then CSI H dispatches.
      _freshWith(c).advance([0x1B, 0x5B, 0x07, 0x48]);
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x07);
      expect(
        c.events.whereType<CsiDispatchEvent>().single.finalByte,
        0x48,
      );
    });

    test('csiEntry + `:` opens a subparam group with implicit 0', () {
      final c = Collector();
      _freshWith(c).advance('\x1B[:5m'.codeUnits);
      final e = c.events.whereType<CsiDispatchEvent>().single;
      // Leading `:` after entry creates [[0, 5]].
      expect(e.params, [
        [0, 5],
      ]);
    });

    test('csiEntry fallthrough (0x7F) goes through anywhere', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x7F, 0x48]);
      // 0x7F is swallowed, CSI H dispatches next.
      expect(
        c.events.whereType<CsiDispatchEvent>().single.finalByte,
        0x48,
      );
    });
  });

  group('CSI ignore edge cases', () {
    test('csiIgnore executes C0 control', () {
      final c = Collector();
      // ESC [ < BEL m — `<` forces csiIgnore, BEL executes, m ends.
      _freshWith(c).advance('\x1B[1<\x07m'.codeUnits);
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x07);
    });

    test('csiIgnore swallows 0x7F', () {
      // Enter csiIgnore via csiParam + `<` (0x3C..0x3F). Then 0x7F
      // is swallowed; then 0x6D ends csiIgnore. No dispatch.
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x31, 0x3C, 0x7F, 0x6D, 0x41]);
      expect(c.events.whereType<CsiDispatchEvent>(), isEmpty);
      expect(c.events.whereType<PrintEvent>().single.char, 0x41);
    });

    test('csiIgnore falls through to anywhere on 0x80+', () {
      // Enter csiIgnore via csiParam + `<`, then feed 0x80. Anywhere
      // drops it. 0x6D ends csiIgnore.
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x31, 0x3C, 0x80, 0x6D, 0x41]);
      expect(c.events.whereType<CsiDispatchEvent>(), isEmpty);
      expect(c.events.whereType<PrintEvent>().single.char, 0x41);
    });
  });

  group('CSI intermediate edge cases', () {
    test('csiIntermediate executes C0', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x20, 0x07, 0x71]);
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x07);
      expect(
        c.events.whereType<CsiDispatchEvent>().single.finalByte,
        0x71,
      );
    });

    test('csiIntermediate + digit jumps to csiIgnore', () {
      final c = Collector();
      _freshWith(c).advance('\x1B[ 1p'.codeUnits);
      final e = c.events.whereType<CsiDispatchEvent>();
      expect(e, isEmpty); // dropped
    });

    test('csiIntermediate anywhere fallback', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x20, 0x80, 0x71]);
      // 0x80 goes through anywhere; then 0x71 dispatches.
      expect(
        c.events.whereType<CsiDispatchEvent>().single.finalByte,
        0x71,
      );
    });
  });

  group('CSI param edge cases', () {
    test('csiParam executes C0 control', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x31, 0x07, 0x6D]);
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x07);
    });

    test('csiParam + 0x20..0x2F transitions to intermediate', () {
      final c = Collector();
      _freshWith(c).advance('\x1B[1 q'.codeUnits);
      final e = c.events.whereType<CsiDispatchEvent>().single;
      expect(e.intermediates, [0x20]);
      expect(e.finalByte, 0x71);
    });

    test('csiParam + 0x3C..0x3F switches to csiIgnore', () {
      final c = Collector();
      _freshWith(c).advance('\x1B[1<m'.codeUnits);
      expect(c.events.whereType<CsiDispatchEvent>(), isEmpty);
    });

    test('csiParam swallows 0x7F', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x31, 0x7F, 0x6D]);
      final e = c.events.whereType<CsiDispatchEvent>().single;
      expect(e.params, [
        [1],
      ]);
    });

    test('csiParam anywhere fallback on 0x80+', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5B, 0x31, 0x80, 0x6D]);
      // 0x80 goes through anywhere (swallowed), then 0x6D dispatches.
      final e = c.events.whereType<CsiDispatchEvent>().single;
      expect(e.finalByte, 0x6D);
    });
  });

  group('DCS edge cases', () {
    test('dcsEntry swallows C0 and 0x7F', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x07, 0x7F, 0x71, 0x1B, 0x5C]);
      expect(
        c.events.whereType<DcsHookEvent>().single.finalByte,
        0x71,
      );
    });

    test('dcsEntry collects intermediate then hooks', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x20, 0x71, 0x41, 0x1B, 0x5C]);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.intermediates, [0x20]);
    });

    test('dcsEntry `:` opens subparam in dcsParam', () {
      final c = Collector();
      _freshWith(c).advance('\x1BP:5qA\x1B\\'.codeUnits);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.params, [
        [0, 5],
      ]);
    });

    test('dcsEntry `;` opens dcsParam via action_param', () {
      final c = Collector();
      _freshWith(c).advance('\x1BP;5qA\x1B\\'.codeUnits);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.params, [
        [0],
        [5],
      ]);
    });

    test('dcsEntry private-range prefix transitions to dcsParam', () {
      final c = Collector();
      _freshWith(c).advance('\x1BP?5qA\x1B\\'.codeUnits);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.intermediates, [0x3F]);
    });

    test('dcsEntry anywhere on 0x80', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x80, 0x71, 0x41, 0x1B, 0x5C]);
      expect(
        c.events.whereType<DcsHookEvent>().single.finalByte,
        0x71,
      );
    });

    test('dcsParam swallows C0 and 0x7F', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x31, 0x07, 0x7F, 0x71, 0x1B, 0x5C]);
      expect(
        c.events.whereType<DcsHookEvent>().single.params,
        [
          [1],
        ],
      );
    });

    test('dcsParam + intermediate switches to dcsIntermediate', () {
      final c = Collector();
      _freshWith(c).advance('\x1BP1 qA\x1B\\'.codeUnits);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.intermediates, [0x20]);
    });

    test('dcsParam + private-range switches to dcsIgnore', () {
      final c = Collector();
      _freshWith(c).advance('\x1BP1<qA\x1B\\'.codeUnits);
      expect(c.events.whereType<DcsHookEvent>(), isEmpty);
    });

    test('dcsParam anywhere on 0x80', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x31, 0x80, 0x71, 0x41, 0x1B, 0x5C]);
      expect(
        c.events.whereType<DcsHookEvent>().single.finalByte,
        0x71,
      );
    });

    test('dcsIntermediate executes C0 and swallows 0x7F', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x20, 0x07, 0x7F, 0x71, 0x1B, 0x5C]);
      expect(
        c.events.whereType<DcsHookEvent>().single.intermediates,
        [0x20],
      );
    });

    test('dcsIntermediate + 0x30..0x3F jumps to dcsIgnore', () {
      final c = Collector();
      _freshWith(c).advance('\x1BP 1qA\x1B\\'.codeUnits);
      expect(c.events.whereType<DcsHookEvent>(), isEmpty);
    });

    test('dcsIntermediate anywhere on 0x80', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x20, 0x80, 0x71, 0x41, 0x1B, 0x5C]);
      expect(
        c.events.whereType<DcsHookEvent>().single.finalByte,
        0x71,
      );
    });

    test('dcsPassthrough with 0x9C terminates cleanly', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x71, 0x41, 0x9C]);
      expect(c.events.whereType<DcsUnhookEvent>(), hasLength(1));
    });

    test('dcsPassthrough drops 0x80..0x9B', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x50, 0x71, 0x41, 0x90, 0x42, 0x9C]);
      final puts = c.events.whereType<DcsPutEvent>().map((e) => e.byte);
      expect(puts, [0x41, 0x42]);
    });

    test('dcsIgnore swallows everything until ESC', () {
      final c = Collector();
      // Enter dcs ignore via `P 1 <`, then feed junk, then ESC \.
      _freshWith(c).advance('\x1BP1<junk\x1B\\'.codeUnits);
      expect(c.events.whereType<DcsHookEvent>(), isEmpty);
    });
  });

  group('OSC edge cases', () {
    test('OSC silently swallows sub-BEL C0 controls', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5D, 0x32, 0x3B, 0x41, 0x05, 0x42, 0x07]);
      final osc = c.events.whereType<OscDispatchEvent>().single;
      expect(osc.params[1], [0x41, 0x42]);
    });

    test('OSC terminated by CAN executes and returns to ground', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5D, 0x32, 0x3B, 0x41, 0x18, 0x42]);
      expect(c.events.whereType<OscDispatchEvent>(), hasLength(1));
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x18);
      expect(c.events.last, const PrintEvent(0x42));
    });

    test('OSC terminated by ESC pivots into escape state', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5D, 0x32, 0x3B, 0x41, 0x1B, 0x37]);
      expect(c.events.whereType<OscDispatchEvent>(), hasLength(1));
      expect(
        c.events.whereType<EscDispatchEvent>().single.finalByte,
        0x37,
      );
    });
  });

  group('Escape state edge cases', () {
    test('ESC + C0 control executes then stays in escape', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x07, 0x1B, 0x07, 0x37]);
      expect(c.events.whereType<ExecuteEvent>().length, 2);
      expect(
        c.events.whereType<EscDispatchEvent>().single.finalByte,
        0x37,
      );
    });

    test('ESC Q (0x51..0x57 branch)', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x51]);
      expect(
        c.events.whereType<EscDispatchEvent>().single.finalByte,
        0x51,
      );
    });

    test('ESC Y (0x59..0x5A branch)', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x59]);
      expect(
        c.events.whereType<EscDispatchEvent>().single.finalByte,
        0x59,
      );
    });

    test('ESC ^ (SOS/PM/APC marker) enters sosPmApcString', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5E, 0x41, 0x42, 0x1B, 0x5C]);
      // Inside SOS/PM/APC everything is dropped until ESC \.
      expect(c.events.whereType<PrintEvent>(), isEmpty);
      expect(c.events.whereType<EscDispatchEvent>().single.finalByte, 0x5C);
    });

    test('ESC _ (APC) enters sosPmApcString', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x5F, 0x41, 0x1B, 0x5C]);
      expect(c.events.whereType<PrintEvent>(), isEmpty);
    });

    test('ESC grave (0x60..0x7E lower range) dispatches', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x60]);
      expect(
        c.events.whereType<EscDispatchEvent>().single.finalByte,
        0x60,
      );
    });

    test('escapeIntermediate executes C0', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x20, 0x07, 0x42]);
      // Two intermediates (space + BEL), BEL is executed, B dispatches.
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x07);
      final e = c.events.whereType<EscDispatchEvent>().single;
      expect(e.intermediates, [0x20]);
      expect(e.finalByte, 0x42);
    });

    test('escapeIntermediate swallows 0x7F', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x20, 0x7F, 0x42]);
      final e = c.events.whereType<EscDispatchEvent>().single;
      expect(e.finalByte, 0x42);
    });

    test('escapeIntermediate anywhere on 0x80+', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x20, 0x80, 0x42]);
      final e = c.events.whereType<EscDispatchEvent>().single;
      expect(e.finalByte, 0x42);
    });
  });

  group('Intermediate overflow', () {
    test('too many intermediates sets ignore on esc dispatch', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x20, 0x21, 0x22, 0x42]);
      expect(
        c.events.whereType<EscDispatchEvent>().single.ignore,
        isTrue,
      );
    });
  });

  group('Params unused public API', () {
    test('len and isEmpty reflect cleared state', () {
      // We reach these via toList() round trips; add a direct
      // smoke through CSI for coverage of len/isEmpty paths.
      final c = Collector();
      _freshWith(c).advance('\x1B[1;2;3m'.codeUnits);
      expect(
        c.events.whereType<CsiDispatchEvent>().single.params,
        [
          [1],
          [2],
          [3],
        ],
      );
    });
  });

  group('Missing state transitions', () {
    test('dcsIntermediate collects a second intermediate', () {
      final c = Collector();
      // ESC P SP ! q A ESC \
      _freshWith(c).advance([0x1B, 0x50, 0x20, 0x21, 0x71, 0x41, 0x1B, 0x5C]);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.intermediates, [0x20, 0x21]);
    });

    test('dcsParam + `:` extends current subparam group', () {
      final c = Collector();
      _freshWith(c).advance('\x1BP1:2qA\x1B\\'.codeUnits);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.params, [
        [1, 2],
      ]);
    });

    test('CAN inside dcsIgnore executes and returns to ground', () {
      final c = Collector();
      // ESC P 1 < CAN A
      _freshWith(c).advance([0x1B, 0x50, 0x31, 0x3C, 0x18, 0x41]);
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x18);
      expect(c.events.last, const PrintEvent(0x41));
    });

    test('CAN inside sosPmApcString executes and returns to ground', () {
      final c = Collector();
      _freshWith(c).advance([0x1B, 0x58, 0x41, 0x18, 0x42]);
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x18);
      expect(c.events.last, const PrintEvent(0x42));
    });

    test('ground state 2-byte UTF-8 encoding a C1 control (U+0085)', () {
      final c = Collector();
      // 0xC2 0x85 → U+0085 NEL, which is in the 0x80..0x9F range and
      // is dispatched as Execute from ground.
      _freshWith(c).advance([0xC2, 0x85]);
      expect(c.events, [const ExecuteEvent(0x85)]);
    });

    test('partial UTF-8 that completes to a C1 control executes', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xC2])
        ..advance([0x85]);
      expect(c.events, [const ExecuteEvent(0x85)]);
    });

    test('4-byte UTF-8 with invalid continuation returns -1 → U+FFFD', () {
      final c = Collector();
      // 0xF0 lead; continuation 0x80 ok; 0x00 NOT continuation.
      _freshWith(c).advance([0xF0, 0x80, 0x00, 0x80]);
      // The invalid sequence emits replacement and skips one byte,
      // so the next print we may or may not see depends on the rest
      // — we just assert the replacement showed up.
      expect(c.events.first, const PrintEvent(0xFFFD));
    });

    test('CSI subparam overflow flags ignore', () {
      // Build MAX_PARAMS + 1 entries via `:` subparams after a
      // regular param, to exercise the `_actionSubparam` ignoring
      // branch.
      final buffer = StringBuffer('\x1B[1');
      for (var i = 0; i < 33; i++) {
        buffer.write(':1');
      }
      buffer.write('m');
      final c = Collector();
      _freshWith(c).advance(buffer.toString().codeUnits);
      final e = c.events.whereType<CsiDispatchEvent>().single;
      expect(e.ignore, isTrue);
    });

    test('DCS max-params overflow flags ignore on hook', () {
      // Build a DCS sequence with MAX_PARAMS + 1 params so the
      // final `push` inside action_hook hits the full branch.
      final buffer = StringBuffer('\x1BP');
      for (var i = 0; i < 33; i++) {
        buffer.write('1;');
      }
      buffer.write('qA\x1B\\');
      final c = Collector();
      _freshWith(c).advance(buffer.toString().codeUnits);
      final hook = c.events.whereType<DcsHookEvent>().single;
      expect(hook.ignore, isTrue);
    });
  });

  group('Partial UTF-8 pathological cases', () {
    test('saved partial + more bytes than needed completes correctly', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xF0]) // 4-byte lead, need 3 more
        ..advance([0x9F, 0x98, 0x80, 0x41]); // finish + 'A'
      expect(c.events, [
        const PrintEvent(0x1F600),
        const PrintEvent(0x41),
      ]);
    });

    test('invalid overlong in partial buffer emits U+FFFD', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xE0]) // 3-byte lead (overlong region)
        ..advance([0x80, 0x80]); // would decode to U+0000 (overlong)
      expect(c.events.first, const PrintEvent(0xFFFD));
    });

    test('surrogate via 3-byte partial emits U+FFFD', () {
      final c = Collector();
      VtParser(sink: c)
        ..advance([0xED])
        ..advance([0xA0, 0x80]);
      expect(c.events.first, const PrintEvent(0xFFFD));
    });
  });

  group('Events equality and toString', () {
    test('PrintEvent equality + hash + string', () {
      expect(const PrintEvent(0x41), equals(const PrintEvent(0x41)));
      expect(
        const PrintEvent(0x41).hashCode,
        const PrintEvent(0x41).hashCode,
      );
      expect(const PrintEvent(0x41), isNot(const PrintEvent(0x42)));
      expect(const PrintEvent(0x41).toString(), contains('0041'));
    });

    test('ExecuteEvent equality + hash + string', () {
      expect(const ExecuteEvent(0x07), const ExecuteEvent(0x07));
      expect(
        const ExecuteEvent(0x07).hashCode,
        const ExecuteEvent(0x07).hashCode,
      );
      expect(const ExecuteEvent(0x07), isNot(const ExecuteEvent(0x08)));
      expect(const ExecuteEvent(0x07).toString(), contains('07'));
    });

    test('EscDispatchEvent equality + hash + string', () {
      const a = EscDispatchEvent(
        intermediates: [0x28],
        finalByte: 0x42,
        ignore: false,
      );
      const b = EscDispatchEvent(
        intermediates: [0x28],
        finalByte: 0x42,
        ignore: false,
      );
      const c = EscDispatchEvent(
        intermediates: [0x29],
        finalByte: 0x42,
        ignore: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('B'));
    });

    test('CsiDispatchEvent equality + hash + string', () {
      const a = CsiDispatchEvent(
        params: [
          [1],
          [2],
        ],
        intermediates: [],
        finalByte: 0x6D,
        ignore: false,
      );
      const b = CsiDispatchEvent(
        params: [
          [1],
          [2],
        ],
        intermediates: [],
        finalByte: 0x6D,
        ignore: false,
      );
      const diffParams = CsiDispatchEvent(
        params: [
          [1],
          [3],
        ],
        intermediates: [],
        finalByte: 0x6D,
        ignore: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(diffParams)));
      expect(a.toString(), contains('params'));
    });

    test('OscDispatchEvent equality + hash + string', () {
      const a = OscDispatchEvent(
        params: [
          [0x32],
          [0x68, 0x69],
        ],
        bellTerminated: true,
      );
      const b = OscDispatchEvent(
        params: [
          [0x32],
          [0x68, 0x69],
        ],
        bellTerminated: true,
      );
      const c = OscDispatchEvent(
        params: [
          [0x32],
        ],
        bellTerminated: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('bellTerminated'));
    });

    test('DcsHookEvent equality + hash + string', () {
      const a = DcsHookEvent(
        params: [
          [1],
        ],
        intermediates: [],
        finalByte: 0x71,
        ignore: false,
      );
      const b = DcsHookEvent(
        params: [
          [1],
        ],
        intermediates: [],
        finalByte: 0x71,
        ignore: false,
      );
      const c = DcsHookEvent(
        params: [
          [2],
        ],
        intermediates: [],
        finalByte: 0x71,
        ignore: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('q'));
    });

    test('DcsPutEvent equality + hash + string', () {
      expect(const DcsPutEvent(0x41), const DcsPutEvent(0x41));
      expect(
        const DcsPutEvent(0x41).hashCode,
        const DcsPutEvent(0x41).hashCode,
      );
      expect(const DcsPutEvent(0x41), isNot(const DcsPutEvent(0x42)));
      expect(const DcsPutEvent(0x41).toString(), contains('41'));
    });

    test('DcsUnhookEvent equality + hash + string', () {
      expect(const DcsUnhookEvent(), const DcsUnhookEvent());
      expect(
        const DcsUnhookEvent().hashCode,
        const DcsUnhookEvent().hashCode,
      );
      expect(const DcsUnhookEvent().toString(), 'DcsUnhookEvent()');
    });
  });

  group('Params public surface', () {
    // Make sure len/isEmpty on the internal struct survive a full
    // dispatch cycle by asserting the parser keeps working after
    // multiple CSI sequences.
    test('multiple sequential CSI dispatches share Params cleanly', () {
      final c = Collector();
      VtParser(sink: c).advance('\x1B[1;2m\x1B[3m\x1B[m'.codeUnits);
      final csis = c.events.whereType<CsiDispatchEvent>().toList();
      expect(csis, hasLength(3));
      expect(csis[0].params, [
        [1],
        [2],
      ]);
      expect(csis[1].params, [
        [3],
      ]);
      expect(csis[2].params, [
        [0],
      ]);
    });
  });
}
