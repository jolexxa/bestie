import 'dart:math';

import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/color.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:test/test.dart';

void main() {
  group('packColor', () {
    test('round-trips the default foreground', () {
      expect(unpackColor(packColor(Color.defaultFg)), Color.defaultFg);
    });

    test('round-trips the default background', () {
      expect(unpackColor(packColor(Color.defaultBg)), Color.defaultBg);
    });

    test('keeps the two defaults distinguishable', () {
      expect(packColor(Color.defaultFg), isNot(packColor(Color.defaultBg)));
    });

    test('round-trips every palette index', () {
      for (var index = 0; index <= 255; index++) {
        final color = IndexedColor(index);
        expect(unpackColor(packColor(color)), color, reason: 'index $index');
      }
    });

    test('round-trips truecolor channel extremes', () {
      const channels = [0, 1, 127, 128, 254, 255];
      for (final r in channels) {
        for (final g in channels) {
          for (final b in channels) {
            final color = RgbColor(r, g, b);
            expect(
              unpackColor(packColor(color)),
              color,
              reason: 'rgb($r, $g, $b)',
            );
          }
        }
      }
    });

    test('round-trips arbitrary truecolors', () {
      final random = Random(20260726);
      for (var i = 0; i < 2000; i++) {
        final color = RgbColor(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
        expect(unpackColor(packColor(color)), color, reason: '$color');
      }
    });

    test('fits every variant in 32 bits', () {
      final colors = <Color>[
        Color.defaultFg,
        Color.defaultBg,
        const IndexedColor(255),
        const RgbColor(255, 255, 255),
      ];
      for (final color in colors) {
        expect(packColor(color), inInclusiveRange(0, 0xFFFFFFFF));
      }
    });

    test('reports the variant without unpacking', () {
      expect(
        colorKind(packColor(Color.defaultFg)),
        ColorKind.defaultForeground,
      );
      expect(
        colorKind(packColor(Color.defaultBg)),
        ColorKind.defaultBackground,
      );
      expect(colorKind(packColor(const IndexedColor(7))), ColorKind.indexed);
      expect(colorKind(packColor(const RgbColor(1, 2, 3))), ColorKind.rgb);
    });

    test('exposes channels without unpacking', () {
      final packed = packColor(const RgbColor(12, 34, 56));

      expect(colorRed(packed), 12);
      expect(colorGreen(packed), 34);
      expect(colorBlue(packed), 56);
    });

    test('exposes the palette index without unpacking', () {
      expect(colorIndex(packColor(const IndexedColor(200))), 200);
    });

    test('hands back a shared instance for palette colors', () {
      final first = unpackColor(packColor(const IndexedColor(42)));
      final second = unpackColor(packColor(const IndexedColor(42)));

      expect(identical(first, second), isTrue);
    });
  });

  group('packStyle', () {
    test('round-trips every attribute bitfield at every width', () {
      for (var attrs = 0; attrs <= 0x3FF; attrs++) {
        for (final width in CellWidth.values) {
          final packed = packStyle(attrs: attrs, width: width);
          expect(styleAttrs(packed), attrs, reason: 'attrs $attrs');
          expect(styleWidth(packed), width, reason: 'width $width @ $attrs');
        }
      }
    });

    test('keeps attributes and width from bleeding into each other', () {
      expect(
        styleWidth(packStyle(attrs: 0x3FF, width: CellWidth.continuation)),
        CellWidth.continuation,
      );
      expect(
        styleAttrs(packStyle(attrs: 0, width: CellWidth.wide)),
        CellAttrs.none,
      );
    });

    test('fits in 16 bits', () {
      expect(
        packStyle(attrs: 0x3FF, width: CellWidth.spacerHead),
        inInclusiveRange(0, 0xFFFF),
      );
    });

    test('maps each width to the columns it covers', () {
      expect(CellWidth.continuation.columns, 0);
      expect(CellWidth.single.columns, 1);
      expect(CellWidth.wide.columns, 2);
      expect(CellWidth.spacerHead.columns, 1);
    });

    test('resolves a cluster width to the cell that carries it', () {
      expect(CellWidth.ofColumns(0), CellWidth.continuation);
      expect(CellWidth.ofColumns(1), CellWidth.single);
      expect(CellWidth.ofColumns(2), CellWidth.wide);
      // A pad covers one column but no cluster ever asks for one —
      // only the wrap point creates it.
      expect(CellWidth.ofColumns(1), isNot(CellWidth.spacerHead));
    });

    test('matches the blank-cell constants the buffer fills with', () {
      expect(
        blankStyle,
        packStyle(attrs: CellAttrs.none, width: CellWidth.single),
      );
      expect(packedDefaultFg, packColor(Color.defaultFg));
      expect(packedDefaultBg, packColor(Color.defaultBg));
    });
  });

  group('GraphemeTable', () {
    test('encodes the empty cluster as zero', () {
      expect(GraphemeTable().encode(''), 0);
    });

    test('round-trips the empty cluster', () {
      final table = GraphemeTable();

      expect(table.decode(table.encode('')), '');
    });

    test('round-trips every ASCII character', () {
      final table = GraphemeTable();
      for (var code = 1; code < 128; code++) {
        final cluster = String.fromCharCode(code);
        expect(table.decode(table.encode(cluster)), cluster);
      }
    });

    test('round-trips a BMP character above ASCII', () {
      final table = GraphemeTable();

      expect(table.decode(table.encode('é')), 'é');
      expect(table.decode(table.encode('中')), '中');
    });

    test('round-trips a single code point above the BMP', () {
      final table = GraphemeTable();

      expect(table.decode(table.encode('😀')), '😀');
    });

    test('round-trips a combining-mark cluster', () {
      final table = GraphemeTable();
      const cluster = 'é';

      expect(table.decode(table.encode(cluster)), cluster);
    });

    test('round-trips a ZWJ emoji cluster', () {
      final table = GraphemeTable();
      const cluster = '👩‍💻';

      expect(table.decode(table.encode(cluster)), cluster);
    });

    test('stores single code points without spilling', () {
      final table = GraphemeTable()
        ..encode('a')
        ..encode('中')
        ..encode('😀');

      expect(table.spilledCount, 0);
    });

    test('reuses one key per distinct cluster', () {
      final table = GraphemeTable();
      const cluster = 'é';

      expect(table.encode(cluster), table.encode(cluster));
      expect(table.spilledCount, 1);
    });

    test('gives distinct clusters distinct keys', () {
      final table = GraphemeTable();

      expect(table.encode('é'), isNot(table.encode('á')));
      expect(table.spilledCount, 2);
    });

    test('keeps many spilled clusters separable', () {
      final table = GraphemeTable();
      final clusters = <String>[
        for (var code = 0x61; code < 0x7B; code++)
          '${String.fromCharCode(code)}́',
      ];
      final codes = [for (final cluster in clusters) table.encode(cluster)];

      for (var i = 0; i < clusters.length; i++) {
        expect(table.decode(codes[i]), clusters[i]);
      }
    });

    test('never collides a spilled key with a code point', () {
      final table = GraphemeTable();

      expect(table.encode('é'), greaterThan(0x10FFFF));
    });

    test('hands back a shared instance for ASCII', () {
      final table = GraphemeTable();
      final code = table.encode('x');

      expect(identical(table.decode(code), table.decode(code)), isTrue);
    });

    test('clear drops the spill table', () {
      final table = GraphemeTable()
        ..encode('é')
        ..clear();

      expect(table.spilledCount, 0);
    });

    test('reassigns keys from zero after clear', () {
      final table = GraphemeTable()
        ..encode('é')
        ..clear();

      const cluster = 'ö';
      expect(table.decode(table.encode(cluster)), cluster);
    });
  });
}
