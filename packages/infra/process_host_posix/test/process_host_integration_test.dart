// Thin shell-out harness for the process_host_posix integration
// scenarios.
//
// Tagged `integration`; each scenario runs in a fresh dart VM via
// `Process.run`. Running them under `dart test` directly is not viable:
// the `test` package installs a process-wide SIGCHLD handler that can
// race child status handling.
@Tags(['integration'])
@TestOn('vm && !windows')
@Timeout(Duration(seconds: 30))
library;

import 'dart:io';

import 'package:test/test.dart';

const _scenarios = <String>[
  'exit_code',
  'term_passthrough',
  'home_matches_host',
  'resize_propagates',
  'signal_death',
  'close_input_blocks_writes',
  'no_premature_eof',
  'stdout_stderr_split',
  'exec_failure_code',
  'kill_targets_grandchild',
  'concurrent_spawn_no_fd_leak',
];

Future<void> _runScenario(String name) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['run', 'test/integration/harness.dart', name],
  );
  final combined = '${result.stdout as String}${result.stderr as String}';
  expect(result.exitCode, 0, reason: 'scenario "$name" failed:\n$combined');
  expect(result.stdout, contains('SCENARIO $name OK'));
}

void main() {
  group('process_host_posix integration (out-of-process)', () {
    for (final name in _scenarios) {
      test(name, () => _runScenario(name));
    }
  });
}
