// Standalone probe for the Linux network jail (seccomp `none`, netns `local`).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:posix_spawner/test_support.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox/test_support.dart';
import 'package:sandbox_linux/sandbox_linux.dart';

/// Broad system read roots so `curl`/`python3` can exec and load libc.
const _systemReadRoots = <String>[
  '/usr',
  '/bin',
  '/sbin',
  '/lib',
  '/lib64',
  '/etc',
  '/opt',
  '/dev',
  '/proc',
  '/sys',
  '/var',
  '/run',
];

/// TEST-NET-1 (RFC 5737): guaranteed-unrouted, so a connect that leaves this
/// box blackholes and curl times out (exit 28), whereas a sandbox-denied
/// connect fails immediately (exit 7).
const _offHostUrl = 'http://192.0.2.1:80/';

/// A single-process loopback round-trip: bind, listen, and connect all on
/// `127.0.0.1` inside the child. Under `local` the child has its *own* netns,
/// so it cannot reach a server in the parent — it is its own loopback peer.
const _intraNsLoopback =
    '''python3 -c 'import socket; s=socket.socket(); '''
    '''s.bind(("127.0.0.1",0)); s.listen(1); c=socket.socket(); '''
    '''c.connect(s.getsockname()); c.close(); s.close()' && echo LOOP_OK''';

Future<void> main(List<String> args) async {
  final tier = switch (args[0]) {
    'none' => NetworkTier.none,
    'local' => NetworkTier.local,
    'all' => NetworkTier.all,
    _ => throw ArgumentError('unknown tier: ${args[0]}'),
  };
  final workspace = args[1];

  final spawner = await const RepoSpawnerLocator().locate();
  if (spawner == null) {
    stdout.writeln('SKIP: spawner not built (run melos run build:spawner)');
    return;
  }

  final runner = ProcessRunner(
    host: PosixProcessHost(spawnerBinaryPath: spawner),
    environment: Platform.environment,
  );
  final probe = await ConfinedProbe.tryAcquire(
    SandboxLinux(fileSystem: const LocalFileSystem()),
    runner,
    SandboxSpec(
      workspaceRoot: workspace,
      readableRoots: _systemReadRoots,
      writableRoots: [workspace],
      network: tier,
    ),
  );
  if (probe == null) {
    stdout.writeln('SKIP: sandbox unavailable');
    return;
  }

  // `local` needs unprivileged netns; where the host cannot grant it the
  // adapter reports it ineligible and there is nothing to assert.
  if (tier == NetworkTier.local &&
      probe.enforcement.network is NetworkIneligibleForConfinement) {
    stdout.writeln('SKIP: local tier ineligible (no unprivileged netns)');
    return;
  }
  if (tier == NetworkTier.local && !File('/usr/bin/python3').existsSync()) {
    stdout.writeln(
      'SKIP: python3 needed for the intra-namespace loopback probe',
    );
    return;
  }

  // `none`/`all` share the host loopback, so the child reaches a server in
  // this trusted parent. `local` is isolated, so it is its own loopback peer.
  HttpServer? loopback;
  var parentHit = false;
  String loopStep;
  if (tier == NetworkTier.local) {
    loopStep = _intraNsLoopback;
  } else {
    loopback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) {
        parentHit = true;
        unawaited(request.response.close());
      });
    loopStep = 'curl -s -m 5 http://127.0.0.1:${loopback.port}/';
  }

  final script = '$loopStep; curl -s -m 2 $_offHostUrl; echo "OFF=\$?"; true';
  final result = await probe.runScript(script);
  await loopback?.close(force: true);

  switch (result) {
    case ProcessCaptureNotStarted(:final failure):
      stdout.writeln('FAIL: spawn refused ($failure)');
      exitCode = 1;
    case ProcessCaptureCompleted(
      stdout: final captured,
      :final stderr,
      :final exit,
    ):
      final childOut = utf8.decode(captured, allowMalformed: true);
      final childErr = utf8.decode(stderr, allowMalformed: true);
      final offExit = RegExp(r'OFF=(\d+)').firstMatch(childOut)?.group(1);
      // curl 28 == the connect left the box and blackholed; anything else means
      // the sandbox refused it before it could leave.
      final offHostBlocked = offExit != '28';
      final loopbackHit = tier == NetworkTier.local
          ? childOut.contains('LOOP_OK')
          : parentHit;
      stdout
        ..writeln('LOOPBACK:${loopbackHit ? 'hit' : 'miss'}')
        ..writeln('OFFHOST:${offHostBlocked ? 'blocked' : 'allowed'}')
        ..writeln('EXIT:$exit')
        ..writeln('CHILD-STDOUT: ${childOut.trim()}')
        ..writeln('CHILD-STDERR: ${childErr.trim()}')
        ..writeln('DONE');
  }
}
