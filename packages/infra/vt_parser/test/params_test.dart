import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

/// We drive the private Params struct through the public parser API
/// because Params itself is intentionally internal. CSI sequences
/// are the easiest way to exercise every mutation path: `;` triggers
/// `push`, `:` triggers `extend`, and the CSI dispatch path finishes
/// with a trailing `push`.
List<List<int>> _parseParams(String csi) {
  final collector = Collector();
  VtParser(sink: collector).advance(csi.codeUnits);
  expect(collector.events, hasLength(1));
  final e = collector.events.single;
  expect(e, isA<CsiDispatchEvent>());
  return (e as CsiDispatchEvent).params;
}

void main() {
  group('Params (via CSI)', () {
    test('bare CSI m emits a single implicit zero parameter', () {
      expect(_parseParams('\x1B[m'), [
        [0],
      ]);
    });

    test('single parameter', () {
      expect(_parseParams('\x1B[5m'), [
        [5],
      ]);
    });

    test('two `;`-separated params', () {
      expect(_parseParams('\x1B[1;2m'), [
        [1],
        [2],
      ]);
    });

    test('leading `;` implies a leading zero', () {
      expect(_parseParams('\x1B[;4m'), [
        [0],
        [4],
      ]);
    });

    test('trailing `;` implies a trailing zero', () {
      expect(_parseParams('\x1B[4;m'), [
        [4],
        [0],
      ]);
    });

    test('subparameters with `:` group onto the previous param', () {
      expect(_parseParams('\x1B[38:2:255:0:0m'), [
        [38, 2, 255, 0, 0],
      ]);
    });

    test('mixed subparameters and parameters', () {
      expect(_parseParams('\x1B[1;38:2:255:0:0;4m'), [
        [1],
        [38, 2, 255, 0, 0],
        [4],
      ]);
    });

    test('saturating arithmetic clamps oversized params at 0xFFFF', () {
      final out = _parseParams('\x1B[9999999m');
      expect(out, hasLength(1));
      expect(out.single.single, 0xFFFF);
    });

    test('max-params overflow sets ignore but still dispatches', () {
      // Build MAX_PARAMS + 1 `;`-separated zeros so the last push
      // overflows. Using `1;` pairs so each leading value is distinct.
      final buffer = StringBuffer('\x1B[');
      for (var i = 0; i < 33; i++) {
        buffer.write('1;');
      }
      buffer.write('p');
      final collector = Collector();
      VtParser(sink: collector).advance(buffer.toString().codeUnits);
      expect(collector.events, hasLength(1));
      final e = collector.events.single as CsiDispatchEvent;
      expect(e.params.length, 32);
      expect(e.ignore, isTrue);
    });
  });
}
