import 'package:bestie_palette_view/bestie_palette_view.dart';
import 'package:test/test.dart';

void main() {
  group('fuzzyRank', () {
    test('empty query keeps every candidate in original order', () {
      expect(fuzzyRank('', ['banana', 'apple']), [0, 1]);
    });

    test('empty candidate list stays empty', () {
      expect(fuzzyRank('stop', []), isEmpty);
    });

    test('non-matches are filtered out', () {
      expect(fuzzyRank('zzz', ['stop all jobs']), isEmpty);
    });

    test('closer matches rank first', () {
      final ranked = fuzzyRank('stop', ['models.download', 'tools.stop']);
      expect(ranked.first, 1);
    });

    test('is case-insensitive', () {
      expect(fuzzyRank('STOP', ['tools.stop']), [0]);
    });
  });
}
