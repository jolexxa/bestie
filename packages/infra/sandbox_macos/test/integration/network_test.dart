// Prove a real process's network reach is filtered by macOS' Seatbelt system.
@Tags(['integration'])
@TestOn('mac-os')
@Timeout(Duration(seconds: 30))
library;

import 'dart:io';

import 'package:test/test.dart';

// The test environment perturbs the Dart VM, so the harness runs under plain
// `dart`, binds the two servers itself, and spawns the confined child (curl)
// via the rust spawner. This test only parses the harness' trusted-side
// reachability report.
Future<ProcessResult> _probe(List<String> args) => Process.run(
  Platform.resolvedExecutable, // dart binary
  ['run', 'test/integration/network_harness.dart', ...args],
);

/// Skips (returns true) when the harness could not confine or had no external
/// interface to serve — so CI without native assets or networking stays green.
bool _skippedIfUnconfined(ProcessResult result) {
  final out = result.stdout as String;
  if (out.contains('SKIP')) {
    markTestSkipped(out.trim());
    return true;
  }
  return false;
}

void main() {
  group('sandbox_macos network jail', () {
    late Directory workspace;

    setUp(() {
      workspace = Directory.systemTemp.createTempSync('cg_net_');
    });

    tearDown(() {
      workspace.deleteSync(recursive: true);
    });

    test('the none tier blocks both loopback and off-host', () async {
      final ws = workspace.resolveSymbolicLinksSync();

      final result = await _probe(['none', ws]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final out = result.stdout as String;
      expect(out, contains('LOOPBACK:miss'), reason: 'none blocks loopback');
      expect(out, contains('OFFHOST:blocked'), reason: 'none blocks off-host');
    });

    test('the local tier reaches loopback but blocks off-host', () async {
      final ws = workspace.resolveSymbolicLinksSync();

      final result = await _probe(['local', ws]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final out = result.stdout as String;
      // If loopback misses, suspect the ::ffff:127.0.0.1 dual-stack gotcha and
      // add explicit (remote ip "127.0.0.1:*") / (remote ip "[::1]:*") rules.
      expect(out, contains('LOOPBACK:hit'), reason: 'local allows loopback');
      expect(out, contains('OFFHOST:blocked'), reason: 'local blocks off-host');
    });

    test('the all tier reaches both loopback and off-host', () async {
      final ws = workspace.resolveSymbolicLinksSync();

      final result = await _probe(['all', ws]);
      if (_skippedIfUnconfined(result)) return;

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      final out = result.stdout as String;
      expect(out, contains('LOOPBACK:hit'), reason: 'all reaches loopback');
      expect(out, contains('OFFHOST:allowed'), reason: 'all reaches off-host');
    });
  });
}
