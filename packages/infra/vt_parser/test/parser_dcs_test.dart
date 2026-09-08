import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

void main() {
  group('DCS', () {
    test('hook + payload + unhook via ST', () {
      final c = Collector();
      // ESC P 1 ; 2 q <payload> ESC \
      // ESC unhooks and transitions to escape; the following `\`
      // then dispatches as a plain EscDispatchEvent, matching
      // alacritty/vte's behaviour. Six events total.
      VtParser(sink: c).advance('\x1BP1;2qABC\x1B\\'.codeUnits);
      expect(c.events.length, 6);
      expect(
        c.events[0],
        const DcsHookEvent(
          params: [
            [1],
            [2],
          ],
          intermediates: [],
          finalByte: 0x71,
          ignore: false,
        ),
      );
      expect(c.events[1], const DcsPutEvent(0x41));
      expect(c.events[2], const DcsPutEvent(0x42));
      expect(c.events[3], const DcsPutEvent(0x43));
      expect(c.events[4], const DcsUnhookEvent());
      expect(
        c.events[5],
        const EscDispatchEvent(
          intermediates: [],
          finalByte: 0x5C,
          ignore: false,
        ),
      );
    });

    test('hook + payload + unhook via 0x9C', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x50, 0x71, 0x41, 0x9C]);
      expect(
        c.events.whereType<DcsHookEvent>().single.finalByte,
        0x71,
      );
      expect(
        c.events.whereType<DcsPutEvent>().map((e) => e.byte),
        [0x41],
      );
      expect(c.events.whereType<DcsUnhookEvent>(), hasLength(1));
    });

    test('DCS passthrough swallows 0x7F', () {
      final c = Collector();
      VtParser(sink: c).advance(
        [0x1B, 0x50, 0x71, 0x41, 0x7F, 0x42, 0x1B, 0x5C],
      );
      final puts = c.events.whereType<DcsPutEvent>().map((e) => e.byte);
      expect(puts, [0x41, 0x42]);
    });

    test('CAN inside DCS unhooks, executes, returns to ground', () {
      final c = Collector();
      VtParser(sink: c).advance([0x1B, 0x50, 0x71, 0x41, 0x18, 0x42]);
      expect(c.events.whereType<DcsUnhookEvent>(), hasLength(1));
      expect(c.events.whereType<ExecuteEvent>().single.byte, 0x18);
      // 0x42 should now be printed in ground state.
      expect(c.events.last, const PrintEvent(0x42));
    });
  });
}
