// Prove a real process's network reach is filtered by Windows' AppContainer.
@Tags(['integration'])
@TestOn('windows')
@Timeout(Duration(seconds: 60))
library;

import 'dart:io';

import 'package:test/test.dart';

// Run dart on the harness so the child spawns from a normal VM; the harness
// provisions the AppContainer, binds the loopback server, and confines curl.
// This test only parses the harness' trusted-side reachability report.
Future<ProcessResult> _probe(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'test/integration/network_harness.dart', ...args],
);

/// Skips (returns true) when the harness could not confine or program the
/// loopback exemption — brush unbuilt, curl absent, or Developer Mode off — so
/// CI without those stays green rather than red.
bool _skippedIfUnconfined(ProcessResult result) {
  final out = result.stdout as String;
  if (out.contains('SKIP')) {
    markTestSkipped(out.trim());
    return true;
  }
  return false;
}

void main() {
  group('sandbox_windows network jail', () {
    late Directory workspace;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('cgw_net_');
    });

    tearDown(() {
      workspace.deleteSync(recursive: true);
    });

    test('the none tier blocks both loopback and off-host', () async {
      final result = await _probe(['none', workspace.path]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final out = result.stdout as String;
      expect(out, contains('LOOPBACK:miss'), reason: 'none blocks loopback');
      expect(out, contains('OFFHOST:blocked'), reason: 'none blocks off-host');
    });

    test('the local tier reaches loopback but blocks off-host', () async {
      final result = await _probe(['local', workspace.path]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final out = result.stdout as String;
      expect(out, contains('LOOPBACK:hit'), reason: 'local allows loopback');
      expect(out, contains('OFFHOST:blocked'), reason: 'local blocks off-host');
    });

    test('the all tier reaches both loopback and off-host', () async {
      final result = await _probe(['all', workspace.path]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final out = result.stdout as String;
      expect(out, contains('LOOPBACK:hit'), reason: 'all reaches loopback');
      expect(out, contains('OFFHOST:allowed'), reason: 'all reaches off-host');
    });
  });
}
