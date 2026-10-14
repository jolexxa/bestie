import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('splitProportionally', () {
    test('splits by weight', () {
      expect(splitProportionally(20, [20, 14, 6]), [10, 7, 3]);
    });

    test('parts always add up to the total', () {
      final parts = splitProportionally(10, [1, 1, 1]);

      expect(parts.fold(0, (sum, part) => sum + part), 10);
    });

    test('gives nothing to parts without weight', () {
      expect(splitProportionally(10, [0, 0]), [0, 0]);
    });

    test('returns no parts for no weights', () {
      expect(splitProportionally(10, []), isEmpty);
    });
  });
}
