// Standalone probe for the macOS network jail.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:posix_spawner/test_support.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox/test_support.dart';
import 'package:sandbox_macos/sandbox_macos.dart';

/// Broad system read roots so `curl` can exec and load dyld.
const _systemReadRoots = <String>[
  '/usr',
  '/bin',
  '/sbin',
  '/System',
  '/Library',
  '/dev',
  '/private',
  '/var',
  '/etc',
  '/opt',
];

/// TEST-NET-1 (RFC 5737): a guaranteed-unrouted address, so a connect that
/// leaves this box blackholes and curl times out (exit 28), whereas a sandbox
/// that denies the connect fails it immediately (exit 7). Unlike this machine's
/// own LAN IP — which macOS routes back through `lo0` and Seatbelt's loopback
/// filter therefore matches — this genuinely leaves the box, so it is a real
/// "external" for the `local` tier.
const _offHostUrl = 'http://192.0.2.1:80/';

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

  // The loopback server lives in this trusted parent; the confined child
  // connects in. macOS `local` filters rather than isolates, so the child
  // shares the host's loopback and reaches this `127.0.0.1` server directly.
  var loopbackHit = false;
  final loopback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  loopback.listen((request) {
    loopbackHit = true;
    unawaited(request.response.close());
  });

  final runner = ProcessRunner(
    host: PosixProcessHost(spawnerBinaryPath: spawner),
    environment: Platform.environment,
  );
  final probe = await ConfinedProbe.tryAcquire(
    SandboxMacos(fileSystem: const LocalFileSystem()),
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
    await loopback.close(force: true);
    return;
  }

  final loopUrl = 'http://127.0.0.1:${loopback.port}/';
  // The loopback body is empty (the server just closes), so the child's stdout
  // carries only the off-host curl exit, which distinguishes a sandbox-denied
  // connect (7) from an allowed-but-blackholed one (28). `true` keeps exit 0.
  final script =
      'curl -s -m 5 $loopUrl; '
      'curl -s -m 2 $_offHostUrl; echo "OFFHOST_EXIT=\$?"; true';

  final result = await probe.runScript(script);
  await loopback.close(force: true);

  switch (result) {
    case ProcessCaptureNotStarted(:final failure):
      stdout.writeln('FAIL: spawn refused ($failure)');
      exitCode = 1;
    case ProcessCaptureCompleted(stdout: final captured):
      final childOut = utf8.decode(captured, allowMalformed: true);
      final offHostExit = RegExp(
        r'OFFHOST_EXIT=(\d+)',
      ).firstMatch(childOut)?.group(1);
      // curl 7 == connect denied by Seatbelt; anything else (28 timeout on the
      // allowed path) means the sandbox let it leave the box.
      final offHostBlocked = offHostExit == '7';
      stdout
        ..writeln('LOOPBACK:${loopbackHit ? 'hit' : 'miss'}')
        ..writeln('OFFHOST:${offHostBlocked ? 'blocked' : 'allowed'}')
        ..writeln('DONE');
  }
}
