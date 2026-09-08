import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

void main() {
  group('ShellLaunchMode.flags', () {
    test('a login shell reads the profile', () {
      expect(ShellLaunchMode.login.flags, ['-l']);
    });

    test('an interactive shell reads the rc files, not the profile', () {
      expect(ShellLaunchMode.interactive.flags, ['-i']);
    });

    test('an interactive login shell adds interactivity on top', () {
      expect(ShellLaunchMode.interactiveLogin.flags, ['-l', '-i']);
    });

    test('a raw shell prepends nothing', () {
      expect(ShellLaunchMode.raw.flags, isEmpty);
    });
  });
}
