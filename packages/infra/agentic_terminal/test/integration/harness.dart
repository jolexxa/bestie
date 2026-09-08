// Standalone integration harness. Run via `dart run` (not under
// `dart test`) because the test package's SIGCHLD handler conflicts
// with the upstream PTY polling loop. The companion test file
// shells out to this script.
import 'dart:async';
import 'dart:io';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:posix_spawner/test_support.dart';
import 'package:process_host_posix/process_host_posix.dart';

late final TerminalHost _host;

typedef Scenario = Future<void> Function();

/// Spawns a terminal, failing the scenario loudly if the spawn is
/// refused.
Future<AgentTerminal> _spawn({
  String? executable,
  List<String> arguments = const [],
  ShellLaunchMode launchMode = ShellLaunchMode.login,
}) async => switch (await _host.spawn(
  rows: 24,
  cols: 80,
  scrollbackBytes: 10000 * 4096,
  environment: Platform.environment,
  executable: executable,
  arguments: arguments,
  launchMode: launchMode,
  forwardHostResize: false,
)) {
  TerminalSpawnSucceeded(:final terminal) => terminal,
  TerminalSpawnFailed(:final failure) => throw StateError(
    'spawn failed: $failure',
  ),
};

final _scenarios = <String, Scenario>{
  'spawn_and_exit': _scenarioSpawnAndExit,
  'send_command': _scenarioSendCommand,
  'exit_code': _scenarioExitCode,
  'resize': _scenarioResize,
  'send_key': _scenarioSendKey,
  'kill': _scenarioKill,
};

Future<void> main(List<String> args) async {
  final spawner = await const RepoSpawnerLocator().locate();
  if (spawner == null) {
    stderr.writeln(
      'agentic_terminal harness: spawner binary not found. Run '
      '`dart tool/build_spawner.dart` from the repo root.',
    );
    exitCode = 2;
    return;
  }
  _host = ProcessHostTerminalHost(
    PosixProcessHost(spawnerBinaryPath: spawner),
  );

  final only = args.isNotEmpty ? args.first : null;
  var failures = 0;
  for (final entry in _scenarios.entries) {
    if (only != null && entry.key != only) continue;
    try {
      await entry.value().timeout(const Duration(seconds: 15));
      stdout.writeln('SCENARIO ${entry.key} OK');
    } on Object catch (e, st) {
      failures++;
      stdout.writeln('SCENARIO ${entry.key} FAIL $e');
      stderr.writeln(st);
    }
  }
  exitCode = failures == 0 ? 0 : 1;
}

void _expect(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}

Future<void> _scenarioSpawnAndExit() async {
  final term = await _spawn(
    executable: '/bin/sh',
    arguments: const ['-c', 'echo HELLO; exit 0'],
    launchMode: ShellLaunchMode.raw,
  );
  final snap = await term.waitForText(
    'HELLO',
    timeout: const Duration(seconds: 5),
  );
  _expect(snap.text.contains('HELLO'), 'text missing HELLO');
  final exit = await term.exit;
  _expect(
    exit is ProcessExited && exit.code == 0,
    'expected ProcessExited(0), got $exit',
  );
  await term.close();
}

Future<void> _scenarioSendCommand() async {
  // Child echoes READY when it's ready to read, so we don't need
  // a hardcoded delay.
  final term = await _spawn(
    executable: '/bin/sh',
    arguments: const ['-c', r'echo READY; read cmd; eval "$cmd"'],
    launchMode: ShellLaunchMode.raw,
  );
  await term.waitForText('READY', timeout: const Duration(seconds: 5));
  term.writeString('echo MARKER\n');
  final snap = await term.waitForText(
    'MARKER',
    timeout: const Duration(seconds: 5),
  );
  _expect(snap.text.contains('MARKER'), 'MARKER not found');
  await term.close();
}

Future<void> _scenarioExitCode() async {
  final term = await _spawn(
    executable: '/bin/sh',
    arguments: const ['-c', 'exit 42'],
    launchMode: ShellLaunchMode.raw,
  );
  final exit = await term.exit;
  _expect(
    exit is ProcessExited && exit.code == 42,
    'expected ProcessExited(42), got $exit',
  );
  await term.close();
}

Future<void> _scenarioResize() async {
  // Child echoes READY then waits for a line before reporting
  // stty size, giving us time to resize.
  final term = await _spawn(
    executable: '/bin/sh',
    arguments: const ['-c', 'echo READY; read _; stty size'],
    launchMode: ShellLaunchMode.raw,
  );
  await term.waitForText('READY', timeout: const Duration(seconds: 5));
  term
    ..resize(rows: 40, cols: 120)
    ..writeString('go\n');
  final snap = await term.waitForText(
    '40 120',
    timeout: const Duration(seconds: 5),
  );
  _expect(snap.text.contains('40 120'), 'resize not reflected');
  await term.close();
}

Future<void> _scenarioSendKey() async {
  // Child echoes READY then reads a line and echoes it back.
  final term = await _spawn(
    executable: '/bin/sh',
    arguments: const [
      '-c',
      r'echo READY; read line; echo "GOT:$line"',
    ],
    launchMode: ShellLaunchMode.raw,
  );
  await term.waitForText('READY', timeout: const Duration(seconds: 5));
  term
    ..writeString('hi')
    ..sendKey(TerminalKey.enter);
  final snap = await term.waitForText(
    'GOT:hi',
    timeout: const Duration(seconds: 5),
  );
  _expect(snap.text.contains('GOT:hi'), 'sendKey enter not received');
  await term.close();
}

Future<void> _scenarioKill() async {
  // sleep produces no output, but we can waitFor the screen to
  // have been painted at least once (the cursor moves on startup).
  final term = await _spawn(
    executable: '/bin/sleep',
    arguments: const ['30'],
    launchMode: ShellLaunchMode.raw,
  );
  // A tiny delay for the fork to settle. sleep doesn't produce
  // any observable output we can waitFor, so this is the one
  // place a small delay is acceptable.
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await term.kill();
  final exit = await term.exit.timeout(const Duration(seconds: 5));
  _expect(
    exit is ProcessSignaled || exit is ProcessExited,
    'expected terminated, got $exit',
  );
  await term.close();
}
