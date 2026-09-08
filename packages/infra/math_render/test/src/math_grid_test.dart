import 'package:math_render/math_render.dart';
import 'package:test/test.dart';

void main() {
  group('MathGrid', () {
    test('line is a single baseline row', () {
      final grid = MathGrid.line('abc');
      expect(grid.lines, ['abc']);
      expect(grid.width, 3);
      expect(grid.height, 1);
      expect(grid.baseline, 0);
      expect(grid.ascent, 0);
      expect(grid.descent, 0);
    });

    test('empty is a zero-width single row', () {
      final grid = MathGrid.empty();
      expect(grid.width, 0);
      expect(grid.height, 1);
      expect(grid.baseline, 0);
      expect(grid.toText(), '');
    });

    test('fromRows keeps rows and baseline', () {
      final grid = MathGrid.fromRows(const ['ab', 'cd', 'ef'], 1);
      expect(grid.height, 3);
      expect(grid.baseline, 1);
      expect(grid.ascent, 1);
      expect(grid.descent, 1);
    });

    test('measures width in grapheme clusters, not code units', () {
      final grid = MathGrid.line('─×≈');
      expect(grid.width, 3);
    });

    test('toText trims trailing spaces per row', () {
      final grid = MathGrid.fromRows(const ['a  ', 'bc '], 0);
      expect(grid.toText(), 'a\nbc');
    });

    test('stretchedRuleTo fills a fresh single row', () {
      final grid = MathGrid.line('─').stretchedRuleTo(4, '─');
      expect(grid.lines, ['────']);
      expect(grid.baseline, 0);
    });

    test('toString reports dimensions', () {
      expect(MathGrid.line('ab').toString(), 'MathGrid(2x1, baseline: 0)');
    });

    group('beside', () {
      test('empty list yields the empty grid', () {
        expect(MathGrid.beside(const []).toText(), '');
      });

      test('places parts left to right on a shared baseline', () {
        final grid = MathGrid.beside([MathGrid.line('a'), MathGrid.line('bc')]);
        expect(grid.toText(), 'abc');
        expect(grid.baseline, 0);
      });

      test('aligns differing baselines and grows the row band', () {
        final tall = MathGrid.fromRows(const ['^', 'x'], 1);
        final grid = MathGrid.beside([MathGrid.line('a'), tall]);
        expect(grid.height, 2);
        expect(grid.baseline, 1);
        expect(grid.lines, [' ^', 'ax']);
      });

      test('ignores zero-width parts', () {
        final grid = MathGrid.beside([
          MathGrid.empty(),
          MathGrid.line('z'),
          MathGrid.empty(),
        ]);
        expect(grid.toText(), 'z');
      });
    });
  });

  group('cell slots', () {
    test('line slots every cell it creates', () {
      final grid = MathGrid.line('abc', 1);
      expect(grid.cells.single.map((c) => c.slot), everyElement(1));
    });

    test('fromRows slots every cell it creates', () {
      final grid = MathGrid.fromRows(const ['ab', 'cd'], 0, 3);
      expect(grid.cells[1].first.slot, 3);
    });

    test('cells default to unslotted', () {
      expect(MathGrid.line('a').cells.single.single.slot, isNull);
    });

    test('beside carries each part its own slots across', () {
      final grid = MathGrid.beside([
        MathGrid.line('a', 0),
        MathGrid.line('b', 1),
      ]);
      expect(grid.slotSketch(), '01');
    });

    test('beside pads with unslotted cells, not the neighbouring slot', () {
      // A tall neighbour lifts the row band; the space that opens up beside a
      // short part is padding and must not extend that part's colour.
      final tall = MathGrid.fromRows(const ['^', 'x'], 1, 1);
      final grid = MathGrid.beside([MathGrid.line('a', 0), tall]);
      expect(grid.slotSketch(), ' 1\n01');
    });

    test('placeCentered carries slots and pads with unslotted cells', () {
      final builder = MathGridBuilder()
        ..placeCentered(MathGrid.line('a', 0), -1)
        ..placeCentered(MathGrid.line('ccc', 1), 1);
      expect(builder.build().slotSketch(), ' 0 \n   \n111');
    });

    test('a stretched rule keeps the slot of the rule it came from', () {
      expect(MathGrid.line('─', 4).stretchedRuleTo(3, '─').slotSketch(), '444');
    });

    test('an empty grid stretches to unslotted cells', () {
      expect(MathGrid.empty().stretchedRuleTo(2, '─').slotSketch(), '  ');
    });

    test('slotSketch draws one character per cell', () {
      final grid = MathGrid.beside([
        MathGrid.line('a', 7),
        MathGrid.line('('),
      ]);
      expect(grid.slotSketch(), '7 ');
    });

    test('slotSketch wraps past nine so it stays one cell wide', () {
      expect(MathGrid.line('x', 12).slotSketch(), '2');
    });
  });

  group('rowRuns', () {
    test('coalesces adjacent cells sharing a slot', () {
      final grid = MathGrid.beside([
        MathGrid.line('ab', 0),
        MathGrid.line('cd', 0),
        MathGrid.line(')'),
      ]);
      expect(grid.rowRuns(), [
        const [MathRun('abcd', 0), MathRun(')', null)],
      ]);
    });

    test('splits a run where the slot changes', () {
      final grid = MathGrid.beside([
        MathGrid.line('a', 0),
        MathGrid.line('b', 1),
      ]);
      expect(grid.rowRuns().single, hasLength(2));
    });

    test('keeps a run of unslotted cells together', () {
      final grid = MathGrid.beside([
        MathGrid.line(' + '),
        MathGrid.line('a', 0),
      ]);
      expect(grid.rowRuns().single.first, const MathRun(' + ', null));
    });

    test('yields one entry per row', () {
      expect(MathGrid.fromRows(const ['ab', 'cd'], 0).rowRuns(), hasLength(2));
    });

    test('yields no runs for an empty row', () {
      expect(MathGrid.empty().rowRuns(), [<MathRun>[]]);
    });
  });

  group('value types', () {
    test('cells compare by cluster and slot', () {
      expect(const MathCell('a'), const MathCell('a'));
      expect(const MathCell('a').hashCode, const MathCell('a').hashCode);
      expect(const MathCell('a'), isNot(const MathCell('b')));
      expect(const MathCell('a'), isNot(const MathCell('a', 1)));
    });

    test('a cell knows whether it shows anything', () {
      expect(MathCell.space.isSpace, isTrue);
      expect(const MathCell('a').isSpace, isFalse);
    });

    test('runs compare by text and slot', () {
      expect(const MathRun('ab', 1), const MathRun('ab', 1));
      expect(const MathRun('ab', 1).hashCode, const MathRun('ab', 1).hashCode);
      expect(const MathRun('ab', 1), isNot(const MathRun('ab', 2)));
      expect(const MathRun('ab', 1), isNot(const MathRun('ab', null)));
    });

    test('descriptions carry the cluster and the slot', () {
      expect(const MathCell('a', 3).toString(), 'MathCell(a, 3)');
      expect(const MathCell('a').toString(), 'MathCell(a, null)');
      expect(const MathRun('ab', 3).toString(), 'MathRun(ab, 3)');
    });
  });

  group('MathGridBuilder', () {
    test('empty builder produces the empty grid', () {
      expect(MathGridBuilder().build().toText(), '');
    });

    test('always keeps the baseline row within the band', () {
      final builder = MathGridBuilder()..placeCentered(MathGrid.line('2'), -1);
      final grid = builder.build();
      expect(grid.height, 2);
      expect(grid.baseline, 1);
      expect(grid.lines, ['2', ' ']);
    });

    test('stacks and centres children of differing widths', () {
      final builder = MathGridBuilder()
        ..placeCentered(MathGrid.line('a'), -1)
        ..placeCentered(MathGrid.line('ccc'), 1);
      final grid = builder.build();
      expect(grid.toText(), ' a\n\nccc');
      expect(grid.baseline, 1);
    });

    test('stretches a rule child to the full width', () {
      final builder = MathGridBuilder()
        ..placeCentered(MathGrid.line('a+b'), -1)
        ..placeCentered(MathGrid.line('─'), 0, stretchAs: '─')
        ..placeCentered(MathGrid.line('c'), 1);
      final grid = builder.build();
      expect(grid.lines, ['a+b', '───', ' c ']);
      expect(grid.baseline, 1);
    });
  });
}
