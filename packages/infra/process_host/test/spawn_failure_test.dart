import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

void main() {
  group('SpawnFailure value semantics', () {
    test('equality and hashCode', () {
      const a = SpawnFailure(
        function: 'posix_spawnp',
        message: 'No such file or directory',
        code: 2,
      );
      const same = SpawnFailure(
        function: 'posix_spawnp',
        message: 'No such file or directory',
        code: 2,
      );

      expect(a, equals(same));
      expect(a.hashCode, same.hashCode);
    });

    test('differs on any field', () {
      const base = SpawnFailure(function: 'f', message: 'm', code: 1);

      expect(
        base,
        isNot(equals(const SpawnFailure(function: 'g', message: 'm', code: 1))),
      );
      expect(
        base,
        isNot(equals(const SpawnFailure(function: 'f', message: 'n', code: 1))),
      );
      expect(
        base,
        isNot(equals(const SpawnFailure(function: 'f', message: 'm', code: 2))),
      );
      expect(base, isNot(equals(Object())));
    });

    test('code defaults to zero when the platform reports none', () {
      expect(const SpawnFailure(function: 'openpty', message: 'nope').code, 0);
    });
  });

  group('SpawnFailure.toString', () {
    test('names the call and the reason', () {
      expect(
        const SpawnFailure(
          function: 'posix_spawnp',
          message: 'No such file or directory',
          code: 2,
        ).toString(),
        'SpawnFailure(posix_spawnp, code=2): No such file or directory',
      );
    });

    test('omits the code when there is not one', () {
      expect(
        const SpawnFailure(function: 'openpty', message: 'nope').toString(),
        'SpawnFailure(openpty): nope',
      );
    });
  });
}
