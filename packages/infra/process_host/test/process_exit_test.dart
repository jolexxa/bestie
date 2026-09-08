import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessExit value semantics', () {
    test('equality and hashCode', () {
      expect(const ProcessExited(0), equals(const ProcessExited(0)));
      expect(
        const ProcessExited(0).hashCode,
        const ProcessExited(0).hashCode,
      );
      expect(const ProcessExited(0), isNot(equals(const ProcessExited(1))));
      expect(
        const ProcessSignaled(9),
        isNot(equals(const ProcessExited(9))),
      );
      expect(const ProcessSignaled(9), equals(const ProcessSignaled(9)));
      expect(
        const ProcessSignaled(9).hashCode,
        const ProcessSignaled(9).hashCode,
      );
      expect(
        const ProcessSignaled(9),
        isNot(equals(const ProcessSignaled(15))),
      );
      expect(const ProcessUnknown(), equals(const ProcessUnknown()));
      expect(
        const ProcessUnknown().hashCode,
        const ProcessUnknown().hashCode,
      );
      expect(
        const ProcessSupervisorLost(),
        equals(const ProcessSupervisorLost()),
      );
      expect(
        const ProcessSupervisorLost().hashCode,
        const ProcessSupervisorLost().hashCode,
      );
      expect(
        const ProcessSupervisorLost(),
        isNot(equals(const ProcessUnknown())),
      );
    });

    test('toString is informative', () {
      expect(const ProcessExited(42).toString(), contains('42'));
      expect(const ProcessSignaled(9).toString(), contains('9'));
      expect(const ProcessUnknown().toString(), contains('Unknown'));
      expect(
        const ProcessSupervisorLost().toString(),
        contains('SupervisorLost'),
      );
    });
  });
}
