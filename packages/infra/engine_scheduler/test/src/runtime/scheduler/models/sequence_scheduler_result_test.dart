import 'package:engine_protocol/engine_protocol.dart';
import 'package:engine_scheduler/engine_scheduler.dart';
import 'package:test/test.dart';

void main() {
  group('SequenceUsage', () {
    test('exposes usage values', () {
      const lease = PrimaryLease(sequence: Sequence(id: 1), fullLimit: 8);

      const usage = SequenceUsage(
        lease: lease,
        tokenCount: 7,
        effectiveLimit: 8,
        positionMin: 2,
      );
      expect(usage.lease, same(lease));
      expect(usage.tokenCount, 7);
      expect(usage.effectiveLimit, 8);
      expect(usage.positionMin, 2);
    });
  });
}
