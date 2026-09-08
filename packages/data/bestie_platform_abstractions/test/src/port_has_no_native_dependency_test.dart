import 'dart:io';

import 'package:test/test.dart';

/// This package is the *port*: it declares what bestie needs from an
/// operating system and nothing about how any particular one provides it.
/// The moment it takes a native dependency, platform-specific code has
/// somewhere to hide, and the next platform has to satisfy machinery it
/// doesn't use — which is exactly how `BestiePosixDataSource`
/// and `NativeFdSink` ended up living here.
///
/// Implementations belong in `bestie_posix` / `bestie_platform_windows`
/// / a platform package. If this test fails, move the code rather than
/// widening the list.
void main() {
  test('the platform port declares no platform-specific dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const forbidden = ['posix_dart', 'win32_dart', 'win32', 'ffi:'];
    final declared = forbidden.where(pubspec.contains).toList();

    expect(
      declared,
      isEmpty,
      reason:
          'bestie_platform_abstractions must stay free of native dependencies; '
          'found $declared. Put the implementation in a platform package '
          'and depend on the interface here instead.',
    );
  });
}
