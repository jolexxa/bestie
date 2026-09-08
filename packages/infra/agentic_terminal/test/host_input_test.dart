import 'package:agentic_terminal/src/host_input.dart';
import 'package:test/test.dart';

void main() {
  group('stripMouseSequences', () {
    test('passes through non-mouse bytes unchanged', () {
      expect(stripMouseSequences([0x41, 0x42, 0x43]), [0x41, 0x42, 0x43]);
    });

    test('passes through regular ESC sequences', () {
      // ESC [ A (arrow up) — not mouse
      expect(stripMouseSequences([0x1B, 0x5B, 0x41]), [0x1B, 0x5B, 0x41]);
    });

    test('strips SGR mouse sequence', () {
      // ESC [ < 35 ; 10 ; 5 M
      final sgr = [
        0x1B,
        0x5B,
        0x3C,
        0x33,
        0x35,
        0x3B,
        0x31,
        0x30,
        0x3B,
        0x35,
        0x4D,
      ];
      expect(stripMouseSequences(sgr), isEmpty);
    });

    test('strips SGR mouse release (lowercase m)', () {
      // ESC [ < 35 ; 10 ; 5 m
      final sgr = [
        0x1B,
        0x5B,
        0x3C,
        0x33,
        0x35,
        0x3B,
        0x31,
        0x30,
        0x3B,
        0x35,
        0x6D,
      ];
      expect(stripMouseSequences(sgr), isEmpty);
    });

    test('strips X10 mouse sequence', () {
      // ESC [ M cb cx cy (6 bytes)
      final x10 = [0x1B, 0x5B, 0x4D, 0x20, 0x30, 0x30];
      expect(stripMouseSequences(x10), isEmpty);
    });

    test('keeps keyboard bytes interleaved with SGR mouse', () {
      // 'a' + SGR mouse + 'b'
      final mixed = [
        0x61, // 'a'
        0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x3B, 0x31, 0x4D, // SGR
        0x62, // 'b'
      ];
      expect(stripMouseSequences(mixed), [0x61, 0x62]);
    });

    test('keeps keyboard bytes interleaved with X10 mouse', () {
      // 'a' + X10 mouse + 'b'
      final mixed = [
        0x61, // 'a'
        0x1B, 0x5B, 0x4D, 0x20, 0x30, 0x30, // X10
        0x62, // 'b'
      ];
      expect(stripMouseSequences(mixed), [0x61, 0x62]);
    });

    test('preserves bytes after incomplete SGR prefix', () {
      // 'a' + ESC [ < with digits but no terminator
      final incomplete = [0x61, 0x1B, 0x5B, 0x3C, 0x33, 0x35];
      // ESC [ < is emitted as-is since no M/m follows, then digits
      expect(
        stripMouseSequences(incomplete),
        [0x61, 0x1B, 0x5B, 0x3C, 0x33, 0x35],
      );
    });

    test('does not eat non-mouse bytes inside ESC [ < prefix', () {
      // ESC [ < followed by CR (0x0D) — NOT valid SGR params
      final tricky = [0x1B, 0x5B, 0x3C, 0x0D];
      expect(stripMouseSequences(tricky), [0x1B, 0x5B, 0x3C, 0x0D]);
    });

    test('CR after mouse sequence is preserved', () {
      // Complete mouse + CR
      final mixed = [
        0x1B,
        0x5B,
        0x3C,
        0x30,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
        0x0D,
      ];
      expect(stripMouseSequences(mixed), [0x0D]);
    });

    test('handles incomplete X10 sequence (too short)', () {
      // ESC [ M + only 2 data bytes (needs 3)
      final incomplete = [0x1B, 0x5B, 0x4D, 0x20, 0x30];
      // Not enough bytes for X10, so individual bytes pass through
      expect(stripMouseSequences(incomplete), [0x1B, 0x5B, 0x4D, 0x20, 0x30]);
    });

    test('handles empty input', () {
      expect(stripMouseSequences([]), isEmpty);
    });

    test('strips consecutive mouse sequences', () {
      // Two SGR sequences back to back
      final two = [
        0x1B,
        0x5B,
        0x3C,
        0x30,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
        0x1B,
        0x5B,
        0x3C,
        0x30,
        0x3B,
        0x32,
        0x3B,
        0x32,
        0x6D,
      ];
      expect(stripMouseSequences(two), isEmpty);
    });
  });

  group('parseHostInput', () {
    test('passes through non-mouse bytes with no events', () {
      final result = parseHostInput([0x61, 0x62, 0x63]);
      expect(result.bytesAsIs, [0x61, 0x62, 0x63]);
      expect(result.bytesWithMouseStripped, [0x61, 0x62, 0x63]);
      expect(result.mouseEvents, isEmpty);
    });

    test('decodes SGR wheel-up press', () {
      // ESC [ < 64 ; 10 ; 5 M
      final sgr = [
        0x1B,
        0x5B,
        0x3C,
        0x36,
        0x34,
        0x3B,
        0x31,
        0x30,
        0x3B,
        0x35,
        0x4D,
      ];
      final result = parseHostInput(sgr);
      expect(result.bytesWithMouseStripped, isEmpty);
      expect(result.mouseEvents, hasLength(1));
      final ev = result.mouseEvents.single;
      expect(ev.button, MouseButton.wheelUp);
      expect(ev.press, isTrue);
      expect(ev.col, 10);
      expect(ev.row, 5);
      expect(ev.shift, isFalse);
    });

    test('decodes SGR wheel-down with shift modifier', () {
      // Cb = 65 (wheel down) | 4 (shift) = 69
      final sgr = [
        0x1B,
        0x5B,
        0x3C,
        0x36,
        0x39,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
      ];
      final ev = parseHostInput(sgr).mouseEvents.single;
      expect(ev.button, MouseButton.wheelDown);
      expect(ev.shift, isTrue);
    });

    test('decodes SGR horizontal wheel (tilt) events', () {
      // Cb 66 / 67 are the horizontal counterparts of wheel up/down.
      List<int> sgrWithCb(List<int> cbDigits) => [
        0x1B,
        0x5B,
        0x3C,
        ...cbDigits,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
      ];

      // '6','6' => 66
      expect(
        parseHostInput(sgrWithCb(const [0x36, 0x36])).mouseEvents.single.button,
        MouseButton.wheelLeft,
      );
      // '6','7' => 67
      expect(
        parseHostInput(sgrWithCb(const [0x36, 0x37])).mouseEvents.single.button,
        MouseButton.wheelRight,
      );
    });

    test('decodes SGR left-button release (lowercase m terminator)', () {
      // ESC [ < 0 ; 1 ; 1 m  (button 0 release)
      final sgr = [
        0x1B,
        0x5B,
        0x3C,
        0x30,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x6D,
      ];
      final ev = parseHostInput(sgr).mouseEvents.single;
      expect(ev.button, MouseButton.left);
      expect(ev.press, isFalse);
    });

    test('decodes X10 wheel-up', () {
      // X10: ESC [ M Cb Cx Cy with Cb = 0x20 + 64 = 0x60
      final x10 = [0x1B, 0x5B, 0x4D, 0x60, 0x21, 0x21];
      final result = parseHostInput(x10);
      expect(result.bytesWithMouseStripped, isEmpty);
      final ev = result.mouseEvents.single;
      expect(ev.button, MouseButton.wheelUp);
      expect(ev.col, 1);
      expect(ev.row, 1);
    });

    test('keeps interleaved keystrokes with mouse events in order', () {
      // 'a' + SGR wheel-up + 'b'
      final mixed = [
        0x61,
        0x1B,
        0x5B,
        0x3C,
        0x36,
        0x34,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
        0x62,
      ];
      final result = parseHostInput(mixed);
      expect(result.bytesWithMouseStripped, [0x61, 0x62]);
      expect(result.mouseEvents, hasLength(1));
      expect(result.mouseEvents.single.button, MouseButton.wheelUp);
    });

    test('bytesAsIs returns the original buffer untouched', () {
      final input = [
        0x1B,
        0x5B,
        0x3C,
        0x36,
        0x34,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
      ];
      expect(parseHostInput(input).bytesAsIs, input);
    });

    test('stripMouseSequences delegates to parseHostInput', () {
      final sgr = [
        0x1B,
        0x5B,
        0x3C,
        0x36,
        0x34,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
        0x61,
      ];
      expect(stripMouseSequences(sgr), [0x61]);
    });

    test('bytesWithWheelStripped removes wheel events but keeps buttons', () {
      // 'a' + SGR left-button-press (cb=0) + SGR wheel-up (cb=64) + 'b'
      const leftPress = [
        0x1B,
        0x5B,
        0x3C,
        0x30,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
      ];
      const wheelUp = [
        0x1B,
        0x5B,
        0x3C,
        0x36,
        0x34,
        0x3B,
        0x31,
        0x3B,
        0x31,
        0x4D,
      ];
      final mixed = [0x61, ...leftPress, ...wheelUp, 0x62];

      final result = parseHostInput(mixed);
      // bytesWithWheelStripped: keep keystrokes + button click, drop wheel.
      expect(
        result.bytesWithWheelStripped,
        [0x61, ...leftPress, 0x62],
      );
      // bytesWithMouseStripped: drop both mouse events.
      expect(result.bytesWithMouseStripped, [0x61, 0x62]);
    });

    test('bytesWithWheelStripped removes X10 wheel events', () {
      // X10 wheel-up: ESC [ M Cb Cx Cy with Cb = 0x60
      const wheel = [0x1B, 0x5B, 0x4D, 0x60, 0x21, 0x21];
      const buttonPress = [0x1B, 0x5B, 0x4D, 0x20, 0x21, 0x21];
      final mixed = [0x61, ...wheel, ...buttonPress];
      expect(
        parseHostInput(mixed).bytesWithWheelStripped,
        [0x61, ...buttonPress],
      );
    });
  });

  group('decodeKittySequence', () {
    test('converts LF to CR (host sends 0x0A for Enter)', () {
      expect(decodeKittySequence([0x0A]), [0x0D]);
    });

    test('passes through plain printable bytes', () {
      expect(decodeKittySequence([0x61]), [0x61]); // 'a'
    });

    test('passes through short sequences', () {
      expect(decodeKittySequence([0x1B]), [0x1B]); // ESC alone
      expect(decodeKittySequence([0x1B, 0x5B]), [0x1B, 0x5B]); // ESC [
    });

    test('passes through non-ESC-bracket sequences', () {
      expect(decodeKittySequence([0x1B, 0x4F, 0x42]), [0x1B, 0x4F, 0x42]);
    });

    test('converts CSI arrow to SS3', () {
      // ESC [ A → ESC O A
      expect(decodeKittySequence([0x1B, 0x5B, 0x41]), [0x1B, 0x4F, 0x41]);
      // ESC [ B → ESC O B
      expect(decodeKittySequence([0x1B, 0x5B, 0x42]), [0x1B, 0x4F, 0x42]);
      // ESC [ C → ESC O C
      expect(decodeKittySequence([0x1B, 0x5B, 0x43]), [0x1B, 0x4F, 0x43]);
      // ESC [ D → ESC O D
      expect(decodeKittySequence([0x1B, 0x5B, 0x44]), [0x1B, 0x4F, 0x44]);
    });

    test('converts CSI Home/End to SS3', () {
      expect(decodeKittySequence([0x1B, 0x5B, 0x48]), [0x1B, 0x4F, 0x48]);
      expect(decodeKittySequence([0x1B, 0x5B, 0x46]), [0x1B, 0x4F, 0x46]);
    });

    test('converts CSI F1-F4 to SS3', () {
      expect(decodeKittySequence([0x1B, 0x5B, 0x50]), [0x1B, 0x4F, 0x50]);
      expect(decodeKittySequence([0x1B, 0x5B, 0x51]), [0x1B, 0x4F, 0x51]);
      expect(decodeKittySequence([0x1B, 0x5B, 0x52]), [0x1B, 0x4F, 0x52]);
      expect(decodeKittySequence([0x1B, 0x5B, 0x53]), [0x1B, 0x4F, 0x53]);
    });

    test('does not convert non-SS3 CSI finals', () {
      // ESC [ Z (shift-tab) — not an SS3 final
      expect(decodeKittySequence([0x1B, 0x5B, 0x5A]), [0x1B, 0x5B, 0x5A]);
    });

    test('decodes kitty Ctrl+C (ESC[99;5u → 0x03)', () {
      final kitty = [0x1B, 0x5B, 0x39, 0x39, 0x3B, 0x35, 0x75];
      expect(decodeKittySequence(kitty), [0x03]);
    });

    test('decodes kitty Ctrl+A (ESC[97;5u → 0x01)', () {
      final kitty = [0x1B, 0x5B, 0x39, 0x37, 0x3B, 0x35, 0x75];
      expect(decodeKittySequence(kitty), [0x01]);
    });

    test('decodes kitty Ctrl+Z (ESC[122;5u → 0x1A)', () {
      // codepoint 122 = 'z', modifier 5 = ctrl
      final kitty = [0x1B, 0x5B, 0x31, 0x32, 0x32, 0x3B, 0x35, 0x75];
      expect(decodeKittySequence(kitty), [0x1A]);
    });

    test('decodes kitty Shift+Tab to ESC[Z (back-tab)', () {
      // ESC[9;2u → ESC[Z (codepoint 9=tab, modifier 2=shift)
      final kitty = [0x1B, 0x5B, 0x39, 0x3B, 0x32, 0x75];
      expect(decodeKittySequence(kitty), [0x1B, 0x5B, 0x5A]);
    });

    test('decodes kitty Ctrl+uppercase letter', () {
      // ESC[65;5u → Ctrl+A (uppercase A=0x41, 0x41-0x40=0x01)
      final kitty = [0x1B, 0x5B, 0x36, 0x35, 0x3B, 0x35, 0x75];
      expect(decodeKittySequence(kitty), [0x01]);
    });

    test('decodes kitty Enter (ESC[13;1u → 0x0D)', () {
      final kitty = [0x1B, 0x5B, 0x31, 0x33, 0x3B, 0x31, 0x75];
      expect(decodeKittySequence(kitty), [0x0D]);
    });

    test('decodes kitty Tab (ESC[9;1u → 0x09)', () {
      final kitty = [0x1B, 0x5B, 0x39, 0x3B, 0x31, 0x75];
      expect(decodeKittySequence(kitty), [0x09]);
    });

    test('decodes kitty Backspace (ESC[127;1u → 0x7F)', () {
      final kitty = [0x1B, 0x5B, 0x31, 0x32, 0x37, 0x3B, 0x31, 0x75];
      expect(decodeKittySequence(kitty), [0x7F]);
    });

    test('decodes kitty Escape (ESC[27;1u → 0x1B)', () {
      final kitty = [0x1B, 0x5B, 0x32, 0x37, 0x3B, 0x31, 0x75];
      expect(decodeKittySequence(kitty), [0x1B]);
    });

    test('decodes kitty u with no modifier', () {
      // ESC[97u → 'a' (codepoint 97, no modifier param)
      final kitty = [0x1B, 0x5B, 0x39, 0x37, 0x75];
      expect(decodeKittySequence(kitty), [0x61]);
    });

    test('handles kitty sub-parameters with colon', () {
      // ESC[13:10;2u → codepoint 13 (from "13:10"), modifier 2
      final kitty = [
        0x1B, 0x5B,
        0x31, 0x33, 0x3A, 0x31, 0x30, // "13:10"
        0x3B, 0x32, // ";2"
        0x75, // u
      ];
      expect(decodeKittySequence(kitty), [0x0D]); // codepoint 13
    });

    test('converts kitty modified arrow to SS3', () {
      // ESC[1;1A → ESC O A (arrow up, modifier 1=none)
      final kitty = [0x1B, 0x5B, 0x31, 0x3B, 0x31, 0x41];
      expect(decodeKittySequence(kitty), [0x1B, 0x4F, 0x41]);
    });

    test('converts kitty shifted arrow to SS3', () {
      // ESC[1;2B → ESC O B (arrow down, modifier 2=shift)
      final kitty = [0x1B, 0x5B, 0x31, 0x3B, 0x32, 0x42];
      expect(decodeKittySequence(kitty), [0x1B, 0x4F, 0x42]);
    });

    test('decodes kitty Alt+a to ESC + a', () {
      // ESC[97;3u → ESC a (codepoint 97='a', modifier 3=alt)
      final kitty = [0x1B, 0x5B, 0x39, 0x37, 0x3B, 0x33, 0x75];
      expect(decodeKittySequence(kitty), [0x1B, 0x61]);
    });

    test('drops kitty release events', () {
      // ESC[97;1:3u → release event (event type 3)
      final release = [
        0x1B, 0x5B,
        0x39, 0x37, // "97"
        0x3B, // ";"
        0x31, 0x3A, 0x33, // "1:3" (modifier 1, event type 3)
        0x75, // "u"
      ];
      expect(decodeKittySequence(release), isEmpty);
    });

    test('forwards kitty press and repeat events', () {
      // ESC[97;1:1u → press (event type 1)
      final press = [
        0x1B,
        0x5B,
        0x39,
        0x37,
        0x3B,
        0x31,
        0x3A,
        0x31,
        0x75,
      ];
      expect(decodeKittySequence(press), [0x61]);

      // ESC[97;1:2u → repeat (event type 2)
      final repeat = [
        0x1B,
        0x5B,
        0x39,
        0x37,
        0x3B,
        0x31,
        0x3A,
        0x32,
        0x75,
      ];
      expect(decodeKittySequence(repeat), [0x61]);
    });

    test('passes through unrecognized CSI sequences', () {
      // ESC [ 5 ~ (page up) — not kitty, not SS3
      final seq = [0x1B, 0x5B, 0x35, 0x7E];
      expect(decodeKittySequence(seq), seq);
    });

    test('handles invalid kitty codepoint gracefully', () {
      // ESC[abc;1u — "abc" is not a number
      final bad = [0x1B, 0x5B, 0x61, 0x62, 0x63, 0x3B, 0x31, 0x75];
      expect(decodeKittySequence(bad), bad);
    });

    test('handles empty params in kitty sequence', () {
      // ESC[u — no params at all
      final empty = [0x1B, 0x5B, 0x75];
      // length == 3, byte[2] = 0x75, not an SS3 final → falls through
      // then length < 4, returns bytes
      expect(decodeKittySequence(empty), empty);
    });
  });

  group('MouseGestureRouter', () {
    List<int> sgr(int cb, int col, int row, {bool press = true}) => [
      0x1B, 0x5B, 0x3C, // ESC [ <
      ...cb.toString().codeUnits,
      0x3B,
      ...col.toString().codeUnits,
      0x3B,
      ...row.toString().codeUnits,
      if (press) 0x4D else 0x6D,
    ];

    // ESC [ M cb cx cy, every field biased by 0x20.
    List<int> x10(int cb, int col, int row) => [
      0x1B, 0x5B, 0x4D, // ESC [ M
      0x20 + cb,
      0x20 + col,
      0x20 + row,
    ];

    List<int> route(
      MouseGestureRouter router,
      List<int> bytes, {
      int dx = 0,
      int dy = 0,
      bool wheelOnly = false,
    }) => router.route(
      bytes,
      dx: dx,
      dy: dy,
      maxCol: 80,
      maxRow: 24,
      wheelOnly: wheelOnly,
    );

    test('translates an inside press and begins capture', () {
      final router = MouseGestureRouter();
      expect(route(router, sgr(0, 10, 5), dx: 2, dy: 3), sgr(0, 8, 2));
      expect(router.capturing, isTrue);
    });

    test('a full inside gesture forwards press, drag and release', () {
      final router = MouseGestureRouter();
      expect(route(router, sgr(0, 10, 5), dx: 1, dy: 1), sgr(0, 9, 4));
      expect(route(router, sgr(32, 12, 6), dx: 1, dy: 1), sgr(32, 11, 5));
      expect(
        route(router, sgr(0, 12, 6, press: false), dx: 1, dy: 1),
        sgr(0, 11, 5, press: false),
      );
      expect(router.capturing, isFalse);
    });

    test('a captured drag and release clamp when they leave the region', () {
      final router = MouseGestureRouter();
      route(router, sgr(0, 10, 5), dx: 5, dy: 1);
      // Dragged past the left edge, released there too: the child still
      // sees the drag pinned to column 1 and the button coming up.
      expect(route(router, sgr(32, 2, 5), dx: 5, dy: 1), sgr(32, 1, 4));
      expect(
        route(router, sgr(0, 2, 5, press: false), dx: 5, dy: 1),
        sgr(0, 1, 4, press: false),
      );
      expect(router.capturing, isFalse);
    });

    test('an outside press forwards nothing, nor does its gesture', () {
      final router = MouseGestureRouter();
      expect(route(router, sgr(0, 100, 5), dx: 1, dy: 1), isEmpty);
      expect(router.capturing, isFalse);
      // The foreign drag crosses the region — still not the child's.
      expect(route(router, sgr(32, 10, 5), dx: 1, dy: 1), isEmpty);
      expect(route(router, sgr(0, 10, 5, press: false), dx: 1, dy: 1), isEmpty);
    });

    test('a shift press stays with the host selection', () {
      final router = MouseGestureRouter();
      // Cb 4 = left press with shift.
      expect(route(router, sgr(4, 10, 5), dx: 1, dy: 1), isEmpty);
      expect(router.capturing, isFalse);
    });

    test('an uncaptured release forwards nothing', () {
      final router = MouseGestureRouter();
      expect(route(router, sgr(0, 10, 5, press: false), dx: 1, dy: 1), isEmpty);
    });

    test('a no-button hover heals a gesture that lost its release', () {
      final router = MouseGestureRouter();
      route(router, sgr(0, 10, 5), dx: 1, dy: 1);
      expect(router.capturing, isTrue);
      // Cb 35 = motion with no button held: authoritative. The router
      // synthesizes the release at the last position the child saw, then
      // forwards the hover itself.
      expect(
        route(router, sgr(35, 12, 6), dx: 1, dy: 1),
        [...sgr(0, 9, 4, press: false), ...sgr(35, 11, 5)],
      );
      expect(router.capturing, isFalse);
    });

    test('a fresh press heals the gesture it interrupts', () {
      final router = MouseGestureRouter();
      route(router, sgr(0, 10, 5), dx: 1, dy: 1);
      expect(
        route(router, sgr(0, 20, 6), dx: 1, dy: 1),
        [...sgr(0, 9, 4, press: false), ...sgr(0, 19, 5)],
      );
      expect(router.capturing, isTrue);
    });

    test('hover motion forwards inside the region only', () {
      final router = MouseGestureRouter();
      expect(route(router, sgr(35, 10, 5), dx: 1, dy: 1), sgr(35, 9, 4));
      expect(route(router, sgr(35, 100, 5), dx: 1, dy: 1), isEmpty);
      expect(router.capturing, isFalse);
    });

    test('wheel forwards inside, drops outside', () {
      final router = MouseGestureRouter();
      expect(route(router, sgr(64, 70, 20), dx: 20, dy: 8), sgr(64, 50, 12));
      expect(route(router, sgr(64, 100, 5), dx: 1, dy: 1), isEmpty);
      expect(router.capturing, isFalse);
    });

    test('wheelOnly forwards wheel and nothing else', () {
      final router = MouseGestureRouter();
      expect(
        route(router, sgr(64, 10, 5), dx: 1, dy: 1, wheelOnly: true),
        sgr(64, 9, 4),
      );
      expect(
        route(router, sgr(0, 10, 5), dx: 1, dy: 1, wheelOnly: true),
        isEmpty,
      );
      expect(router.capturing, isFalse);
    });

    test('entering wheelOnly mid-gesture closes it out for the child', () {
      final router = MouseGestureRouter();
      route(router, sgr(0, 10, 5), dx: 1, dy: 1);
      expect(
        route(router, sgr(64, 12, 6), dx: 1, dy: 1, wheelOnly: true),
        [...sgr(0, 9, 4, press: false), ...sgr(64, 11, 5)],
      );
      expect(router.capturing, isFalse);
    });

    test('routes a mouse sequence between keyboard bytes', () {
      final router = MouseGestureRouter();
      final input = [0x61, ...sgr(0, 10, 5), 0x62];
      expect(route(router, input, dx: 1, dy: 1), [
        0x61,
        ...sgr(0, 9, 4),
        0x62,
      ]);
    });

    test('leaves a malformed SGR sequence intact', () {
      // Only two params — not a valid cb;col;row triple.
      final malformed = [0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x4D];
      final router = MouseGestureRouter();
      expect(route(router, malformed, dx: 1, dy: 1), malformed);
    });

    test('translates an X10 gesture, clamping its stray release', () {
      final router = MouseGestureRouter();
      expect(route(router, x10(0, 10, 5), dx: 2, dy: 3), x10(0, 8, 2));
      expect(router.capturing, isTrue);
      // X10 has no `m` terminator — a release is button 3 in the low bits.
      expect(route(router, x10(3, 1, 1), dx: 2, dy: 3), x10(3, 1, 1));
      expect(router.capturing, isFalse);
    });

    test('drops an X10 press outside and heals in the X10 dialect', () {
      final router = MouseGestureRouter();
      expect(route(router, x10(0, 100, 5), dx: 1, dy: 1), isEmpty);
      route(router, x10(0, 10, 5), dx: 1, dy: 1);
      // The synthesized release arrives as X10, matching the press.
      expect(
        route(router, x10(35, 12, 6), dx: 1, dy: 1),
        [...x10(3, 9, 4), ...x10(35, 11, 5)],
      );
    });
  });
}
