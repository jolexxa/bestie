import 'package:markdown/markdown.dart' as md;
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/internal/table_renderer.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

String _flatten(InlineSpan span) {
  final buffer = StringBuffer();
  span.computeToPlainText(buffer);
  return buffer.toString();
}

md.Element _parseTable(String source) {
  final nodes = buildMarkdownDocument().parse(source);
  return nodes.whereType<md.Element>().firstWhere((e) => e.tag == 'table');
}

void main() {
  group('TableRenderer', () {
    test('renders a simple table', () {
      // Header `longer_header` is wider than body cell `1` — exercises the
      // "keep existing max width" branch when scanning the body row.
      final table = _parseTable(
        '| longer_header | b |\n|---|---|\n| 1 | 2 |',
      );
      final span = TableRenderer.render(table);
      final text = _flatten(span);
      expect(text, contains('longer_header'));
      expect(text, contains('1'));
      // Borders.
      expect(text, contains('┌'));
      expect(text, contains('├'));
      expect(text, contains('└'));
    });

    test('returns an empty span for an empty/malformed table', () {
      // Construct an md.Element with no rows.
      final table = md.Element('table', []);
      expect(_flatten(TableRenderer.render(table)), '');
    });

    test(
      'proportionally shrinks columns when natural width exceeds maxWidth',
      () {
        final long = 'x' * 50;
        final table = _parseTable(
          '| h1 | h2 |\n|---|---|\n| $long | $long |',
        );
        final span = TableRenderer.render(table, maxWidth: 30);
        // Body should still be present (possibly wrapped).
        expect(_flatten(span), contains('x'));
      },
    );

    test('falls back to minimum width when maxWidth is too small', () {
      final table = _parseTable(
        '| a | b | c | d | e |\n|---|---|---|---|---|\n| 1 | 2 | 3 | 4 | 5 |',
      );
      // 5 cols * (3 min + 3 overhead) + 1 = 31, so maxWidth=5 forces minimums.
      final span = TableRenderer.render(table, maxWidth: 5);
      expect(_flatten(span), contains('│'));
    });

    test('wraps cell contents when content exceeds the column width', () {
      final table = _parseTable(
        '| h |\n|---|\n| ${'word ' * 10} |',
      );
      final span = TableRenderer.render(table, maxWidth: 20);
      final text = _flatten(span);
      // Multiple lines means we wrapped.
      expect(text.split('\n').length, greaterThan(3));
    });

    test('breaks a single long word when it exceeds the column width', () {
      final longWord = 'a' * 30;
      final table = _parseTable('| h |\n|---|\n| $longWord |');
      final span = TableRenderer.render(table, maxWidth: 15);
      final text = _flatten(span);
      expect(text, contains('a'));
    });

    test('reclaims excess width when proportional+min over-allocates', () {
      // 5 columns with natural widths [20, 1, 1, 1, 1]. With maxWidth=31:
      //   overhead = 3*5+1 = 16, available = 15.
      //   Proportional pass: col 0 = floor(20*15/24) = 12, others = max(3,
      //   floor(1*15/24)) = max(3, 0) = 3. Allocated = 24, remaining = -9.
      //   This triggers the "reclaim excess" third pass that shrinks the
      //   widest column back down toward the budget.
      final wide = 'x' * 20;
      final table = _parseTable(
        '| $wide | a | b | c | d |\n'
        '|---|---|---|---|---|\n'
        '| $wide | 1 | 2 | 3 | 4 |',
      );
      final span = TableRenderer.render(table, maxWidth: 31);
      expect(_flatten(span), contains('1'));
    });

    test('wraps a long word that appears after a shorter word', () {
      final big = 'b' * 20;
      final table = _parseTable(
        '| h |\n|---|\n| short $big |',
      );
      final span = TableRenderer.render(table, maxWidth: 15);
      // The wrap path: short word fits, then big word forces a line break and
      // is itself broken across lines.
      expect(_flatten(span), contains('short'));
      expect(_flatten(span), contains('b'));
    });

    test(
      'hands rounding leftovers to the column with the largest unfilled flex',
      () {
        // 3 columns with non-trivial flex ratios that don't divide evenly,
        // forcing the leftover-redistribution loop to fire.
        final table = _parseTable(
          '| aa | bb cc | dd ee ff |\n'
          '|---|---|---|\n'
          '| aa | bb cc | dd ee ff |',
        );
        final span = TableRenderer.render(table, maxWidth: 20);
        // Smoke-test that the cells render with content intact.
        expect(_flatten(span), contains('dd'));
      },
    );

    test('preserves a narrow column at its required width when another column '
        'has a wide body — fixes the "Action → Act/ion" squeeze', () {
      // Old behavior: proportional shrink by natural width forced the
      // Action column down to 3 chars even though its widest word ("status")
      // is 6, causing mid-word wraps. New behavior: each column gets at
      // least the width of its longest word before flex is distributed.
      final table = _parseTable(
        '| Action | What happens |\n'
        '|---|---|\n'
        '| graze | Decreases hunger increases milk consumes energy |\n'
        '| status | Shows current values |',
      );
      final span = TableRenderer.render(table, maxWidth: 40);
      final text = _flatten(span);
      // Every token in the Action column must survive intact (no mid-word
      // split). If wrapped, "Action" would appear as "Act\n" + "ion".
      expect(text, contains('Action'));
      expect(text, contains('graze'));
      expect(text, contains('status'));
    });
  });
}
