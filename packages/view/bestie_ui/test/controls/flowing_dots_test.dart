import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart' hide isNotEmpty;
import 'package:test/test.dart';

const _width = 8;
const int _lastTick = flowingDotsTicksPerPass - 1;

String _frame(int tick) => flowingDotsFrame(tick: tick, width: _width);

const _glyphs = ['·', '•', '●'];

/// Cells of [frame] holding a dot of any size.
List<int> _dots(String frame) => [
  for (final (cell, glyph) in frame.split('').indexed)
    if (_glyphs.contains(glyph)) cell,
];

void main() {
  group('flowingDotsFrame', () {
    test('always fills exactly the requested width', () {
      for (var tick = 0; tick < flowingDotsTicksPerPass * 3; tick++) {
        expect(_frame(tick).length, _width);
      }
    });

    test('parks three small dots at the left edge', () {
      expect(_frame(0), '···     ');
    });

    test('has them all parked at the right edge as a pass ends', () {
      expect(_frame(_lastTick), '     ···');
    });

    test('sends the innermost dot first and leaves the rest parked', () {
      final beforeSecondLeaves = (flowingDotsStagger * _lastTick).floor();
      final early = flowingDotsFrame(tick: beforeSecondLeaves, width: 20);
      expect(early, startsWith('·· '));
      expect(_dots(early), hasLength(3));
    });

    test('never loses or duplicates a dot', () {
      for (var tick = 0; tick < flowingDotsTicksPerPass * 2; tick++) {
        expect(_dots(_frame(tick)), hasLength(3), reason: 'tick $tick');
      }
    });

    test('swells a dot on its way over', () {
      final swollen = [
        for (var tick = 0; tick <= _lastTick; tick++)
          if (_frame(tick).contains('●')) tick,
      ];
      expect(swollen, isNotEmpty);
      expect(_frame(0), isNot(contains('●')));
      expect(_frame(_lastTick), isNot(contains('●')));
    });

    test('only ever moves toward the far edge within a pass', () {
      var previous = _dots(_frame(0)).last;
      for (var tick = 1; tick <= _lastTick; tick++) {
        final lead = _dots(_frame(tick)).last;
        expect(lead, greaterThanOrEqualTo(previous));
        previous = lead;
      }
    });

    test('sends them back on the next pass', () {
      const nextPass = flowingDotsTicksPerPass;
      expect(_frame(nextPass), '     ···');
      expect(_frame(nextPass + _lastTick), '···     ');
      expect(
        _dots(_frame(nextPass + _lastTick ~/ 2)).first,
        lessThan(_width - 3),
      );
    });

    test('is a pure function of its tick', () {
      expect(_frame(5), _frame(5));
      expect(_frame(0), isNot(_frame(_lastTick)));
    });
  });

  group('flowingDotsTrackWidth', () {
    test('takes all of a bounded width', () {
      expect(flowingDotsTrackWidth(12), 12);
    });

    test('never shrinks below a single cell', () {
      expect(flowingDotsTrackWidth(0), 1);
    });

    test('falls back to the default width when unbounded', () {
      expect(flowingDotsTrackWidth(double.infinity), flowingDotsDefaultWidth);
    });
  });

  group('FlowingDots', () {
    test('spans the available width and keeps the blob moving', () async {
      await testNocterm('flowing dots', size: const Size(12, 1), (
        tester,
      ) async {
        await tester.pumpComponent(const FlowingDots());
        final first = tester.terminalState.getText();
        expect(first, '···         ');

        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();
        expect(tester.terminalState.getText(), isNot(first));
      });
    });

    test('uses the default width when the track is unbounded', () async {
      await testNocterm('unbounded dots', size: const Size(20, 1), (
        tester,
      ) async {
        await tester.pumpComponent(
          const Row(mainAxisSize: MainAxisSize.min, children: [FlowingDots()]),
        );
        expect(tester.terminalState.getText(), startsWith('···      '));
        expect(tester.terminalState.getText().trimRight(), hasLength(3));
      });
    });

    test('takes its color from the caller', () async {
      await testNocterm('colored dots', size: const Size(12, 1), (
        tester,
      ) async {
        await tester.pumpComponent(const FlowingDots(color: Colors.red));
        expect(tester.terminalState.getCellAt(0, 0)?.style.color, Colors.red);
      });
    });
  });
}
