import 'dart:io';

import 'package:test/test.dart';

/// Doing the clipboard through Win32 rather than a helper process is what
/// lets this package stay free of `process_host`.
void main() {
  test('the Windows platform declares no POSIX or process dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const forbidden = ['process_host', 'posix_dart', 'system_info2'];
    final declared = forbidden.where(pubspec.contains).toList();

    expect(
      declared,
      isEmpty,
      reason:
          'bestie_platform_windows must reach the OS through win32_dart; '
          'found $declared.',
    );
  });
}
