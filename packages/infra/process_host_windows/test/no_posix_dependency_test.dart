import 'dart:io';

import 'package:test/test.dart';

/// The Windows process host goes native through `win32_dart` — never through
/// `posix_dart`. The fence is coarse but mechanical: if this package ever
/// takes a POSIX dependency, POSIX-shaped code has somewhere to hide on
/// Windows. See `windows.md`'s Tier-1 boundary note.
void main() {
  test('declares no POSIX dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec.contains('posix_dart'),
      isFalse,
      reason:
          'process_host_windows must implement the contract through '
          'win32_dart, not posix_dart.',
    );
  });
}
