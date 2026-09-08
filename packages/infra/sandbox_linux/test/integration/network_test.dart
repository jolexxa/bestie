// Prove a real process's network reach is confined on Linux (seccomp / netns).
@Tags(['integration'])
@TestOn('linux')
@Timeout(Duration(seconds: 30))
library;

import 'dart:io';

import 'package:test/test.dart';

// The harness runs under plain `dart`, binds any loopback server itself, and
// spawns the confined child via the rust spawner. This file parses the harness'
// trusted-side reachability report.
Future<ProcessResult> _probe(List<String> args) => Process.run(
  Platform.resolvedExecutable,
  ['run', 'test/integration/network_harness.dart', ...args],
);

/// Skips (returns true) when the harness could not confine, had no native
/// assets, or the tier is ineligible on this host — so CI stays green.
bool _skippedIfUnconfined(ProcessResult result) {
  final out = result.stdout as String;
  if (out.contains('SKIP')) {
    markTestSkipped(out.trim());
    return true;
  }
  return false;
}

void main() {
  group('sandbox_linux network jail', () {
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
      // The child is its own loopback peer inside its netns.
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
