// Standalone probe for the Windows AppContainer network jail. Provisions a real
// profile, applies the tier's capability + loopback exemption, and spawns curl
// confined through the real WindowsProcessHost.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:process_host/process_host.dart';
import 'package:process_host_windows/process_host_windows.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox/test_support.dart';
import 'package:sandbox_windows/sandbox_windows.dart';
import 'package:win32_dart/test_support.dart';

import 'harness_support.dart';

/// TEST-NET-1 (RFC 5737): a guaranteed-unrouted address. A connect that leaves
/// the box blackholes and curl times out (exit 28); a connect the sandbox
/// refuses fails immediately (a non-timeout exit). So the exit code separates
/// "internet reachable" from "network denied" without a live external server.
const _offHostUrl = 'http://192.0.2.1:80/';

Future<void> main(List<String> args) async {
  final tier = switch (args[0]) {
    'none' => NetworkTier.none,
    'local' => NetworkTier.local,
    'all' => NetworkTier.all,
    _ => throw ArgumentError('unknown tier: ${args[0]}'),
  };
  final workspace = args[1];

  final brush = await _locateBrush();
  if (brush == null) {
    stdout.writeln('SKIP: brush not built (run `melos run build:brush`)');
    return;
  }
  final conpty = await const RepoConsoleHostLocator().locate();
  if (conpty == null) {
    stdout.writeln('SKIP: console host not downloaded');
    return;
  }
  final curl = _locateCurl();
  if (curl == null) {
    stdout.writeln('SKIP: curl.exe not found in System32');
    return;
  }

  // The loopback server lives in this trusted parent; the confined child
  // connects in. The AppContainer reaches 127.0.0.1 only when the loopback
  // exemption is programmed, so a hit here is the exemption working.
  var loopbackHit = false;
  final loopback = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  loopback.listen((request) {
    loopbackHit = true;
    unawaited(request.response.close());
  });

  final runner = ProcessRunner(
    host: WindowsProcessHost(conptyLibraryPath: conpty),
    // brush's `true`/`echo` come from the bundled userland on PATH; curl is
    // referenced by absolute path so no PATH split has to find it.
    environment: {...Platform.environment, 'PATH': File(brush).parent.path},
  );
  final guard = SandboxWindows(await spawnWorker());
  final probe = await ConfinedProbe.tryAcquire(
    guard,
    runner,
    SandboxSpec(
      workspaceRoot: workspace,
      readableRoots: [workspace],
      writableRoots: [workspace],
      network: tier,
    ),
  );
  if (probe == null) {
    stdout.writeln('SKIP: sandbox unavailable');
    await loopback.close(force: true);
    await guard.dispose();
    return;
  }

  // local/all want loopback, which needs Developer Mode. When it degraded, the
  // exemption never programmed, so skip rather than assert a hit we can't get.
  if (tier != NetworkTier.none &&
      probe.enforcement.network is! NetworkConfined) {
    stdout.writeln('SKIP: loopback exemption unavailable (Developer Mode off)');
    await loopback.close(force: true);
    await _cleanup(guard, workspace);
    return;
  }

  try {
    String slash(String path) => path.replaceAll(r'\', '/');
    final loopUrl = 'http://127.0.0.1:${loopback.port}/';
    // The loopback body is empty, so the child's stdout carries only the
    // off-host exit — allowed-but-blackholed (28) vs denied (anything else).
    final script =
        '"${slash(curl)}" -s -m 5 "$loopUrl"; '
        '"${slash(curl)}" -s -m 2 "$_offHostUrl"; '
        r'echo "OFFHOST_EXIT=$?"; true';

    final result = await probe.runScript(script, shell: brush);
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
        // Timeout (28) means the connect left the box; anything else means the
        // AppContainer refused it before it could.
        final offHostBlocked = offHostExit != '28';
        stdout
          ..writeln('LOOPBACK:${loopbackHit ? 'hit' : 'miss'}')
          ..writeln('OFFHOST:${offHostBlocked ? 'blocked' : 'allowed'}')
          ..writeln('DONE');
    }
  } finally {
    await _cleanup(guard, workspace);
  }
}

/// Reverses the workspace profile, ACLs, and loopback exemption so nothing
/// persists, then closes the worker isolate so this process can exit.
Future<void> _cleanup(SandboxWindows guard, String workspace) async {
  await guard.reverseWorkspace(
    profileName: guard.profileNameFor(workspace),
    workspaceRoot: workspace,
    widenedRoots: const [],
  );
  await guard.dispose();
}

/// The repo-built brush, resolved from this package's location so it is correct
/// from any working directory. Null when it has not been built.
Future<String?> _locateBrush() async {
  final libRoot = await Isolate.resolvePackageUri(
    Uri.parse('package:sandbox_windows/'),
  );
  if (libRoot == null) return null;
  final brush = libRoot
      .resolve(
        '../../agent_shell/assets/native/windows/x64/shell/bin/brush.exe',
      )
      .toFilePath();
  return File(brush).existsSync() ? brush : null;
}

/// The system curl, readable+executable by every AppContainer via `ALL
/// APPLICATION PACKAGES`. Null on the rare host without it.
String? _locateCurl() {
  final root = Platform.environment['SystemRoot'];
  if (root == null) return null;
  final curl = '$root\\System32\\curl.exe';
  return File(curl).existsSync() ? curl : null;
}
