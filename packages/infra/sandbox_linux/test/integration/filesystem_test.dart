// Prove a real process is confined by Linux' Landlock LSM.
@Tags(['integration'])
@TestOn('linux')
@Timeout(Duration(seconds: 30))
library;

import 'dart:io';

import 'package:test/test.dart';

// The test environment perturbs the Dart VM, so the harness runs under plain
// `dart`, acquires the sandbox, and spawns the confined child (/bin/sh) via the
// rust spawner. This file only sets up fixtures and asserts the effect.
Future<ProcessResult> _probe(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'test/integration/filesystem_harness.dart', ...args],
);

/// Skips (returns true) when the harness could not confine — spawner unbuilt or
/// the kernel cannot confine — so CI without native assets stays green.
bool _skippedIfUnconfined(ProcessResult result) {
  final out = result.stdout as String;
  if (out.contains('SKIP')) {
    markTestSkipped(out.trim());
    return true;
  }
  return false;
}

void main() {
  group('sandbox_linux filesystem jail', () {
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

    test('a denied file is unreadable while its sibling is not', () async {
      final ws = workspace.resolveSymbolicLinksSync();
      final ro = outside.resolveSymbolicLinksSync();
      File('$ro/sibling.txt').writeAsStringSync('SIBLINGDATA');
      File('$ro/secret.txt').writeAsStringSync('SECRETDATA');

      final result = await _probe(['read_deny', ws, ro, '$ro/secret.txt']);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final output = result.stdout as String;
      expect(output, contains('SIBLINGDATA'), reason: 'sibling stays readable');
      expect(
        output,
        isNot(contains('SECRETDATA')),
        reason: 'the denied file must not be readable',
      );
    });

    test('a glob-denied file is unreadable while a sibling is not', () async {
      final ws = workspace.resolveSymbolicLinksSync();
      final ro = outside.resolveSymbolicLinksSync();
      Directory('$ro/secrets').createSync();
      File('$ro/secrets/allowed.txt').writeAsStringSync('ALLOWEDDATA');
      File('$ro/secrets/blocked.key').writeAsStringSync('BLOCKEDKEY');

      final result = await _probe(['glob_deny', ws, ro, '$ro/secrets/*.key']);
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

    test('a denied directory still lists but hides its contents', () async {
      final ws = workspace.resolveSymbolicLinksSync();
      final ro = outside.resolveSymbolicLinksSync();
      Directory('$ro/.ssh').createSync();
      File('$ro/.ssh/id').writeAsStringSync('KEYDATA');
      File('$ro/notes.txt').writeAsStringSync('NOTESDATA');

      final result = await _probe(['list_hide', ws, ro, '$ro/.ssh']);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final output = result.stdout as String;
      // The name leaks (ls of the parent lists it) — the accepted trade.
      expect(output, contains('.ssh'), reason: 'ls lists the denied name');
      // But its contents do not.
      expect(
        output,
        isNot(contains('KEYDATA')),
        reason: 'the denied directory contents must not be readable',
      );
      // And an allowed sibling still reads.
      expect(output, contains('NOTESDATA'), reason: 'sibling stays readable');
    });
  });
}
