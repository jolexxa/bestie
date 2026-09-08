// Prove a real process is confined by Windows' AppContainer.
@Tags(['integration'])
@TestOn('windows')
@Timeout(Duration(seconds: 60))
library;

import 'dart:io';

import 'package:test/test.dart';

// Run dart on the harness so the child spawns from a normal VM, then let the
// harness provision the AppContainer and confine brush. The trusted parent
// reads the disk afterwards.
Future<ProcessResult> _probe(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'test/integration/filesystem_harness.dart', ...args],
);

/// Skips (returns true) when the harness could not confine — brush unbuilt, the
/// console host absent, or the sandbox unavailable — so CI without native
/// assets stays green rather than red.
bool _skippedIfUnconfined(ProcessResult result) {
  final out = result.stdout as String;
  if (out.contains('SKIP')) {
    markTestSkipped(out.trim());
    return true;
  }
  return false;
}

void main() {
  group('sandbox_windows filesystem model', () {
    late Directory workspace;
    late Directory outside;
    late Directory home;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('cgw_ws_');
      outside = Directory.systemTemp.createTempSync('cgw_out_');
      home = Directory.systemTemp.createTempSync('cgw_home_');
    });

    tearDown(() {
      workspace.deleteSync(recursive: true);
      outside.deleteSync(recursive: true);
      home.deleteSync(recursive: true);
    });

    test('write lands inside the jail and is denied outside', () async {
      final ws = workspace.path;
      final out = outside.path;

      final result = await _probe(['write', ws, out]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('$ws\\inside.txt').existsSync(),
        isTrue,
        reason: 'in-jail write should land',
      );
      expect(
        File('$out\\outside.txt').existsSync(),
        isFalse,
        reason: 'out-of-jail write must be denied',
      );
    });

    test('a workspace recreated since its grant is granted again', () async {
      final ws = workspace.path;
      final out = outside.path;

      final result = await _probe(['recreate', ws, out]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('$ws\\inside.txt').existsSync(),
        isTrue,
        reason: 'the write must land after the ACE was lost and re-granted',
      );
      expect(File('$out\\outside.txt').existsSync(), isFalse);
    });

    test('a write grant taken back is denied again', () async {
      final ws = workspace.path;
      final out = outside.path;

      final result = await _probe(['widen', ws, out]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File('$out\\before.txt').existsSync(),
        isFalse,
        reason: 'a write beyond the workspace must be denied',
      );
      expect(
        File('$out\\during.txt').existsSync(),
        isTrue,
        reason: 'the widened write should land',
      );
      expect(
        File('$out\\after.txt').existsSync(),
        isFalse,
        reason: 'the narrowed write must be denied again',
      );
    });

    test('broad read reaches home, but a carved secret stays hidden', () async {
      final ws = workspace.path;
      final out = outside.path;
      File('${home.path}\\readable.txt').writeAsStringSync('HOMEDATA');
      final secret = File('${home.path}\\secret.txt')
        ..writeAsStringSync('SECRETDATA');

      final result = await _probe([
        'broad_read',
        ws,
        out,
        home.path,
        secret.path,
      ]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final output = result.stdout as String;
      expect(
        output,
        contains('HOMEDATA'),
        reason: 'home is readable via the shared capability',
      );
      expect(
        output,
        isNot(contains('SECRETDATA')),
        reason: 'the carved secret must not be readable',
      );
    });
  });
}
