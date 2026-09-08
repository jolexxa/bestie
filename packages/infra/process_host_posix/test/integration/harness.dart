// Standalone integration harness for `process_host_posix`.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:posix_spawner/test_support.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';

late final PosixProcessHost _host;

typedef Scenario = Future<void> Function();

/// Spawns on a pty, failing the scenario loudly if the spawn is
/// refused. Host resize forwarding is off by default — these scenarios
/// drive [PosixRunningProcess.resize] explicitly and must not race a
/// real `SIGWINCH` from the terminal running them.
RunningProcess _terminal({
  required Map<String, String> environment,
  String? executable,
  List<String> arguments = const [],
  int? initialRows,
  int? initialCols,
  ShellLaunchMode launchMode = ShellLaunchMode.login,
  bool forwardHostResize = false,
}) => _unwrap(
  _host.terminal(
    executable: executable,
    arguments: arguments,
    environment: environment,
    initialRows: initialRows,
    initialCols: initialCols,
    launchMode: launchMode,
    forwardHostResize: forwardHostResize,
  ),
);

/// Spawns with three pipes, failing the scenario loudly if the spawn is
/// refused.
RunningProcess _piped({
  required Map<String, String> environment,
  String? executable,
  List<String> arguments = const [],
  ShellLaunchMode launchMode = ShellLaunchMode.raw,
}) => _unwrap(
  _host.piped(
    executable: executable,
    environment: environment,
    arguments: arguments,
    launchMode: launchMode,
  ),
);

RunningProcess _unwrap(ProcessSpawnResult result) => switch (result) {
  ProcessSpawnSucceeded(:final process) => process,
  ProcessSpawnFailed(:final failure) => throw StateError(
    'spawn failed: $failure',
  ),
};

final _scenarios = <String, Scenario>{
  'exit_code': _scenarioExitCode,
  'term_passthrough': _scenarioTermPassthrough,
  'home_matches_host': _scenarioHomeMatchesHost,
  'resize_propagates': _scenarioResizePropagates,
  'signal_death': _scenarioSignalDeath,
  'close_input_blocks_writes': _scenarioCloseInputBlocksWrites,
  'no_premature_eof': _scenarioNoPrematureEof,
  'stdout_stderr_split': _scenarioStdoutStderrSplit,
  'exec_failure_code': _scenarioExecFailureCode,
  'kill_targets_grandchild': _scenarioKillTargetsGrandchild,
  'concurrent_spawn_no_fd_leak': _scenarioConcurrentSpawnNoFdLeak,
};

Future<void> main(List<String> args) async {
  final spawner = await const RepoSpawnerLocator().locate();
  if (spawner == null) {
    stderr.writeln(
      'process_host_posix harness: spawner binary not found. Run '
      '`dart run melos run build:spawner` before tests.',
    );
    exitCode = 2;
    return;
  }
  _host = PosixProcessHost(spawnerBinaryPath: spawner);
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

/// Fails with [reason] unless [action] rejects the call with a
/// [StateError], which is how a closed stdin announces itself.
void _expectRejected(void Function() action, String reason) {
  var rejected = false;
  try {
    action();
    // The StateError is the assertion target, not a bug to propagate.
    // ignore: avoid_catching_errors
  } on StateError {
    rejected = true;
  }
  _expect(rejected, reason);
}

Future<String> _collectUntil(
  Stream<List<int>> output,
  String marker, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final buffer = StringBuffer();
  await for (final chunk in output.timeout(timeout)) {
    buffer.write(utf8.decode(chunk, allowMalformed: true));
    if (buffer.toString().contains(marker)) break;
  }
  return buffer.toString();
}

Future<String> _drain(Stream<List<int>> output) async {
  final buffer = StringBuffer();
  await for (final chunk in output) {
    buffer.write(utf8.decode(chunk, allowMalformed: true));
  }
  return buffer.toString();
}

Future<void> _scenarioExitCode() async {
  final proc = _terminal(
    environment: Platform.environment,
    executable: '/bin/sh',
    arguments: const ['-c', 'echo HELLOMARKER; exit 42'],
  );
  final output = await _collectUntil(proc.stdout, 'HELLOMARKER');
  _expect(output.contains('HELLOMARKER'), 'no marker in output: $output');

  final exit = await proc.exit;
  _expect(
    exit is ProcessExited && exit.code == 42,
    'expected ProcessExited(42), got $exit',
  );
  await proc.close();
}

Future<void> _scenarioTermPassthrough() async {
  final proc = _terminal(
    environment: {...Platform.environment, 'TERM': 'xterm-256color'},
    executable: '/bin/sh',
    arguments: const ['-c', r'printf "T=%s\n" "$TERM"; exit 0'],
  );
  final output = await _collectUntil(proc.stdout, 'T=');
  _expect(
    output.contains('T=xterm-256color'),
    'expected TERM=xterm-256color, got: $output',
  );
  await proc.exit;
  await proc.close();
}

Future<void> _scenarioHomeMatchesHost() async {
  final expected = Platform.environment['HOME']!;
  final proc = _terminal(
    environment: Platform.environment,
    executable: '/bin/sh',
    arguments: const ['-c', r'printf "H=%s\n" "$HOME"; exit 0'],
  );
  final output = await _collectUntil(proc.stdout, 'H=');
  _expect(output.contains('H=$expected'), 'expected H=$expected, got: $output');
  await proc.exit;
  await proc.close();
}

Future<void> _scenarioResizePropagates() async {
  final proc =
      _terminal(
          environment: Platform.environment,
          executable: '/bin/sh',
          arguments: const ['-c', r'read _; printf "SZ=%s\n" "$(stty size)"'],
          initialRows: 24,
          initialCols: 80,
        )
        ..resize(rows: 40, cols: 120)
        ..writeString('go\n');

  final output = await _collectUntil(proc.stdout, 'SZ=');
  _expect(output.contains('SZ=40 120'), 'expected SZ=40 120, got: $output');
  await proc.exit;
  await proc.close();
}

Future<void> _scenarioSignalDeath() async {
  final proc = _terminal(
    environment: Platform.environment,
    executable: '/bin/sleep',
    arguments: const ['30'],
    launchMode: ShellLaunchMode.raw,
  );
  await Future<void>.delayed(const Duration(milliseconds: 200));
  final killed = await proc.kill(force: true);
  _expect(killed, 'kill returned false');

  final exit = await proc.exit.timeout(const Duration(seconds: 5));
  _expect(
    exit is ProcessSignaled && exit.signal == 9,
    'expected ProcessSignaled(9), got $exit',
  );
  await proc.close();
}

/// Regression for the slave-fd race: parent closing its slave fd before
/// the helper had opened its own made the master see EOF before any
/// bytes arrived (symptom: shell connected but blank).
Future<void> _scenarioNoPrematureEof() async {
  for (var i = 0; i < 20; i++) {
    final proc = _terminal(
      environment: Platform.environment,
      executable: '/bin/sh',
      arguments: const ['-c', 'echo START; sleep 0.1'],
      launchMode: ShellLaunchMode.raw,
    );
    try {
      final output = await _collectUntil(
        proc.stdout,
        'START',
        timeout: const Duration(seconds: 1),
      );
      _expect(
        output.contains('START'),
        'iter $i: missing START (likely premature EOF)',
      );
    } finally {
      await proc.kill(force: true);
      await proc.exit.timeout(const Duration(seconds: 2));
      await proc.close();
    }
  }
}

Future<void> _scenarioCloseInputBlocksWrites() async {
  final proc = _terminal(
    environment: Platform.environment,
    executable: '/bin/sh',
    arguments: const ['-c', 'sleep 5'],
  );
  await proc.closeStdin();

  _expectRejected(
    () => proc.writeBytes(const [0x68, 0x69]),
    'writeBytes did not throw after closeStdin',
  );
  _expectRejected(
    () => proc.writeString('hi'),
    'writeString did not throw after closeStdin',
  );

  await proc.kill(force: true);
  await proc.exit.timeout(const Duration(seconds: 5));
  await proc.close();
}

/// Piped mode delivers stdout and stderr on separate streams.
Future<void> _scenarioStdoutStderrSplit() async {
  final proc = _piped(
    environment: Platform.environment,
    executable: '/bin/sh',
    arguments: const ['-c', 'echo TO_OUT; echo TO_ERR 1>&2; exit 5'],
  );
  final outFuture = _drain(proc.stdout);
  final errFuture = _drain(proc.stderr);
  final exit = await proc.exit;
  final out = (await outFuture).trim();
  final err = (await errFuture).trim();

  _expect(out == 'TO_OUT', 'stdout was "$out", expected TO_OUT');
  _expect(err == 'TO_ERR', 'stderr was "$err", expected TO_ERR');
  _expect(
    exit is ProcessExited && exit.code == 5,
    'expected ProcessExited(5), got $exit',
  );
  await proc.close();
}

/// A missing target surfaces as the helper's distinctive EXIT_EXEC (106)
/// forwarded through the status pipe — not a hang or a lost supervisor.
Future<void> _scenarioExecFailureCode() async {
  final proc = _piped(
    environment: Platform.environment,
    executable: '/definitely/not/a/real/binary',
  );
  final exit = await proc.exit.timeout(const Duration(seconds: 5));
  _expect(
    exit is ProcessExited && exit.code == 106,
    'expected ProcessExited(106), got $exit',
  );
  await proc.close();
}

/// `kill` must signal the target grandchild (pid over the status pipe),
/// not the supervisor. If it hit the supervisor, the target would live
/// on and `exit` would never resolve.
Future<void> _scenarioKillTargetsGrandchild() async {
  final proc = _piped(
    environment: Platform.environment,
    executable: '/bin/sh',
    arguments: const ['-c', 'sleep 30'],
  );
  final targetPid = await proc.pid;
  _expect(targetPid > 0, 'target pid was $targetPid');

  final killed = await proc.kill(force: true);
  _expect(killed, 'kill returned false');

  final exit = await proc.exit.timeout(const Duration(seconds: 5));
  _expect(
    exit is ProcessSignaled && exit.signal == 9,
    'expected ProcessSignaled(9) (target died), got $exit',
  );

  // The target pid should now be gone: `kill` reports whether the pid
  // was signalable at all, so a second attempt must come back false.
  final probe = await proc.kill(force: true);
  _expect(!probe, 'target pid $targetPid still signalable after death');
  await proc.close();
}

/// Two children spawned back-to-back are independent: killing one
/// resolves its exit promptly while the other keeps running. Guards the
/// CLOEXEC + file_actions design against cross-spawn fd leaks (a leaked
/// write end would keep the killed child's pipes from ever EOF-ing).
Future<void> _scenarioConcurrentSpawnNoFdLeak() async {
  final a = _piped(
    environment: Platform.environment,
    executable: '/bin/sh',
    arguments: const ['-c', 'sleep 30'],
  );
  final b = _piped(
    environment: Platform.environment,
    executable: '/bin/sh',
    arguments: const ['-c', 'sleep 30'],
  );
  await a.pid;
  await b.pid;

  await a.kill(force: true);
  final aExit = await a.exit.timeout(const Duration(seconds: 5));
  _expect(
    aExit is ProcessSignaled && aExit.signal == 9,
    'child A did not resolve to signaled(9): got $aExit',
  );

  // B must still be alive — its exit must NOT have resolved.
  var bResolved = false;
  unawaited(b.exit.then((_) => bResolved = true));
  await Future<void>.delayed(const Duration(milliseconds: 200));
  _expect(!bResolved, 'child B exited unexpectedly (leak/cross-wire)');

  await b.kill(force: true);
  await b.exit.timeout(const Duration(seconds: 5));
  await a.close();
  await b.close();
}
