@TestOn('!windows')
@Tags(['integration'])
library;

import 'dart:io';

import 'package:test/test.dart';

const _scenarios = <String>[
  'spawn_and_exit',
  'send_command',
  'exit_code',
  'resize',
  'send_key',
  'kill',
];

Future<void> _runScenario(String name) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['run', 'test/integration/harness.dart', name],
  );
  final combined = '${result.stdout as String}${result.stderr as String}';
  expect(
    result.exitCode,
    0,
    reason: 'scenario "$name" failed:\n$combined',
  );
  expect(result.stdout, contains('SCENARIO $name OK'));
}

void main() {
  group('AgentTerminal integration (out-of-process)', () {
    for (final name in _scenarios) {
      test(name, () => _runScenario(name));
    }
  });
}
