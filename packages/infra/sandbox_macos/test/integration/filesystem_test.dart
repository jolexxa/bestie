// Prove a real process is sandbox'd by macOS' Seatbelt system.
@Tags(['integration'])
@TestOn('mac-os')
@Timeout(Duration(seconds: 30))
library;

import 'dart:io';

import 'package:test/test.dart';

// Run the dart process on our file system harness with these args to see
// what happens to the child process that we sandbox. The test environment
// messes with the Dart VM, so we need to run our harness with dart normally,
// then use our spawner binary (written in rust) to spawn our child process
// in the sandbox. whew.
Future<ProcessResult> _probe(List<String> args) => Process.run(
  Platform.resolvedExecutable, // dart binary
  ['run', 'test/integration/filesystem_harness.dart', ...args],
);

/// Skips (returns true) when the harness could not confine — spawner unbuilt
/// or the sandbox unavailable — so CI without native assets stays green.
bool _skippedIfUnconfined(ProcessResult result) {
  final out = result.stdout as String;
  if (out.contains('SKIP')) {
    markTestSkipped(out.trim());
    return true;
  }
  return false;
}

void main() {
  group('sandbox_macos filesystem jail', () {
    late Directory workspace;
    late Directory outside;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('cg_ws_');
      outside = Directory.systemTemp.createTempSync('cg_out_');
    });

    tearDown(() {
      workspace.deleteSync(recursive: true);
      outside.deleteSync(recursive: true);
    });

    test('write lands inside the jail and is denied outside', () async {
      final ws = workspace.resolveSymbolicLinksSync();
      final out = outside.resolveSymbolicLinksSync();

      final result = await _probe(['write', ws, out]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('$ws/inside.txt').existsSync(),
        isTrue,
        reason: 'in-jail write should land',
      );
      expect(
        File('$out/outside.txt').existsSync(),
        isFalse,
        reason: 'out-of-jail write must be denied',
      );
    });

    test('the null device stays writable inside the jail', () async {
      final ws = workspace.resolveSymbolicLinksSync();
      final out = outside.resolveSymbolicLinksSync();

      final result = await _probe(['devnull', ws, out]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        result.stdout as String,
        contains('NULL_WRITABLE'),
        reason: 'git opens /dev/null read-write on every command',
      );
    });

    test('a listed secret is unreadable while its sibling is not', () async {
      final ws = workspace.resolveSymbolicLinksSync();
      final out = outside.resolveSymbolicLinksSync();
      File('$ws/sibling.txt').writeAsStringSync('SIBLINGDATA');
      File('$ws/secret.txt').writeAsStringSync('SECRETDATA');

      final result = await _probe(['read_deny', ws, out, '$ws/secret.txt']);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final output = result.stdout as String;
      expect(output, contains('SIBLINGDATA'), reason: 'sibling stays readable');
      expect(
        output,
        isNot(contains('SECRETDATA')),
        reason: 'the denied secret must not be readable',
      );
    });

    test('a glob-denied file is unreadable while a sibling is not', () async {
      final ws = workspace.resolveSymbolicLinksSync();
      final out = outside.resolveSymbolicLinksSync();
      Directory('$ws/secrets').createSync();
      File('$ws/secrets/allowed.txt').writeAsStringSync('ALLOWEDDATA');
      File('$ws/secrets/blocked.key').writeAsStringSync('BLOCKEDKEY');

      final result = await _probe(['glob_deny', ws, out, '$ws/secrets/*.key']);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final output = result.stdout as String;
      expect(
        output,
        contains('ALLOWEDDATA'),
        reason: 'the non-matching sibling stays readable',
      );
      expect(
        output,
        isNot(contains('BLOCKEDKEY')),
        reason: 'the glob-matched key must not be readable',
      );
    });
  });
}
