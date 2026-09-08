@TestOn('!windows')
library;

import 'package:posix_dart/posix_dart.dart';
import 'package:test/test.dart';

void main() {
  group('PosixEnv', () {
    test('setenv then getenv round-trips through the C environment', () {
      const key = 'BESTIE_POSIX_ENV_TEST_ROUNDTRIP';
      expect(PosixEnv.getenv(key), isNull);
      expect(PosixEnv.setenv(key, 'moo'), 0);
      expect(PosixEnv.getenv(key), 'moo');
    });

    test('setenv overwrites by default', () {
      const key = 'BESTIE_POSIX_ENV_TEST_OVERWRITE';
      expect(PosixEnv.setenv(key, 'first'), 0);
      expect(PosixEnv.setenv(key, 'second'), 0);
      expect(PosixEnv.getenv(key), 'second');
    });

    test('setenv with overwrite:false keeps the existing value', () {
      const key = 'BESTIE_POSIX_ENV_TEST_NO_OVERWRITE';
      expect(PosixEnv.setenv(key, 'first'), 0);
      expect(PosixEnv.setenv(key, 'second', overwrite: false), 0);
      expect(PosixEnv.getenv(key), 'first');
    });
  });
}
