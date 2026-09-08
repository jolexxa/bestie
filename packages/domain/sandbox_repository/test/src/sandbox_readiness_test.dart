import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';

void main() {
  group('SandboxInitializationFailed', () {
    test('is equal to another failure for the same reason', () {
      const failed = SandboxInitializationFailed('no acl');

      expect(failed, const SandboxInitializationFailed('no acl'));
      expect(
        failed.hashCode,
        const SandboxInitializationFailed('no acl').hashCode,
      );
      expect(failed, isNot(const SandboxInitializationFailed('declined')));
    });
  });
}
