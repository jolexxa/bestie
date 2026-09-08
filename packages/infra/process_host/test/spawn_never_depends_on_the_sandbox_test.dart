import 'dart:io';

import 'package:test/test.dart';

/// `Sandbox` is an empty marker declared here so a spawn can carry a
/// confinement it cannot read. The direction is one-way: the sandbox
/// layer depends on this package, never the reverse.
///
/// If this test fails, the dependency has been inverted and there is a
/// cycle waiting. Keep the marker opaque and put the confinement
/// vocabulary in the `sandbox` packages.
void main() {
  test('the spawn contract declares no dependency on the sandbox layer', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const forbidden = [
      'sandbox',
      'sandbox_macos',
      'sandbox_linux',
      'sandbox_windows',
    ];
    final declared = forbidden
        .where(
          (name) => RegExp('^\\s+$name:', multiLine: true).hasMatch(pubspec),
        )
        .toList();

    expect(
      declared,
      isEmpty,
      reason:
          'process_host must not depend on the sandbox layer; found '
          '$declared. `Sandbox` stays an empty marker here and the '
          'confinement that implements it lives above.',
    );
  });
}
