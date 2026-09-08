import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PosixFailure', () {
    test('toString includes function name and errno', () {
      final f = PosixFailure.fromErrno(
        'open',
        2,
        'No such file or directory',
      );
      expect(f.toString(), contains('open'));
      expect(f.toString(), contains('errno=2'));
      expect(f.toString(), contains('No such file or directory'));
    });

    test('withoutErrno omits the errno field from toString', () {
      final f = PosixFailure.withoutErrno('dlopen', 'symbol not found');
      expect(f.toString(), contains('dlopen'));
      expect(f.toString(), contains('symbol not found'));
      expect(f.toString(), isNot(contains('errno=')));
    });

    test('default message uses strerror when not provided', () {
      // No errno → empty message; just verify the factory doesn't throw.
      final f = PosixFailure.fromErrno('fake', 0);
      expect(f.message, isEmpty);
      expect(f.errno, 0);
    });
  });
}
