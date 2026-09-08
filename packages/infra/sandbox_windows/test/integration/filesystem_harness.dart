// Standalone probe for the Windows AppContainer filesystem model: read the
// world, write the jail. Grants the shared bestie-read capability broad read
// (with a secret hole), provisions a real workspace profile with write, spawns
// brush carrying the capability through the real WindowsProcessHost, and prints
// what the child could touch.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:process_host/process_host.dart';
import 'package:process_host_windows/process_host_windows.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox/test_support.dart';
import 'package:sandbox_windows/sandbox_windows.dart';
import 'package:win32_dart/test_support.dart';
import 'package:win32_dart/win32_dart.dart';

import 'harness_support.dart';

Future<void> main(List<String> args) async {
  final scenario = args[0];
  final workspace = args[1];
  final outside = args[2];

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
  final binDir = File(brush).parent.path;

  // The harness's own capability, so reversing it never strips the app's.
  final derived = Capabilities(win32).sidFor('bestie.read.harness');
  if (derived is! SidSucceeded) {
    stdout.writeln('FAIL: could not derive the harness read capability');
    return;
  }
  final capabilitySid = derived.sid.asString()!;
  derived.sid.close();

  // Broad read is the shared capability's job: the bundled userland's bin (so
  // brush and coreutils resolve) plus, for the read scenario, a seeded "home"
  // with a secret carved out.
  final readRoots = <String>[binDir, if (scenario == 'broad_read') args[3]];
  final holes = <String>[if (scenario == 'broad_read') args[4]];

  final spec = SandboxSpec(
    workspaceRoot: workspace,
    readableRoots: [workspace, ...readRoots],
    writableRoots: [workspace],
  );

  final runner = ProcessRunner(
    host: WindowsProcessHost(conptyLibraryPath: conpty),
    // Put the bundled userland on PATH so brush resolves the multicall.
    environment: {...Platform.environment, 'PATH': binDir},
  );
  final guard = SandboxWindows(
    await spawnWorker(),
    bestieReadCapabilitySid: capabilitySid,
  );

  final sharedRead = await guard.grantSharedRead(
    capabilitySid: capabilitySid,
    readRoots: readRoots,
    holes: holes,
  );
  if (sharedRead != null) {
    stdout.writeln('FAIL: shared read grant ($sharedRead)');
    await guard.dispose();
    return;
  }

  final probe = await ConfinedProbe.tryAcquire(guard, runner, spec);
  if (probe == null) {
    stdout.writeln('SKIP: sandbox unavailable');
    await _cleanup(guard, capabilitySid, readRoots, holes, workspace);
    return;
  }

  try {
    if (scenario == 'widen') {
      await _widenThenNarrow(guard, runner, spec, probe, outside, brush);
      return;
    }

    String slash(String path) => path.replaceAll(r'\', '/');
    final ws = slash(workspace);
    final out = slash(outside);
    final script = switch (scenario) {
      'write' || 'recreate' =>
        'echo inside > "$ws/inside.txt"; '
            'echo outside > "$out/outside.txt"; true',
      'broad_read' =>
        'coreutils cat "${slash(args[3])}/readable.txt"; echo; '
            'coreutils cat "${slash(args[4])}"; true',
      _ => throw ArgumentError('unknown scenario: $scenario'),
    };

    // The workspace is recreated (every ACE gone) before the returning acquire.
    final confined = scenario == 'recreate'
        ? await _returnToRecreated(guard, runner, spec, workspace)
        : probe;
    if (confined == null) {
      stdout.writeln('FAIL: could not re-acquire the recreated workspace');
      exitCode = 1;
      return;
    }

    final result = await confined.runScript(script, shell: brush);
    switch (result) {
      case ProcessCaptureNotStarted(:final failure):
        stdout.writeln('FAIL: spawn refused ($failure)');
        exitCode = 1;
      case ProcessCaptureCompleted(
        stdout: final captured,
        :final stderr,
        :final exit,
      ):
        stdout
          ..write(utf8.decode(captured, allowMalformed: true))
          ..writeln('\nEXIT:$exit')
          ..writeln(
            'CHILD-STDERR: '
            '${utf8.decode(stderr, allowMalformed: true).trim()}',
          )
          ..writeln('DONE');
    }
  } finally {
    await _cleanup(guard, capabilitySid, readRoots, holes, workspace);
  }
}

/// Writes to [outside] under the base [spec], again once widened to write
/// there, and once more after narrowing back: the last write proves the
/// narrowing took.
Future<void> _widenThenNarrow(
  SandboxWindows guard,
  ProcessRunner runner,
  SandboxSpec spec,
  ConfinedProbe base,
  String outside,
  String brush,
) async {
  final out = outside.replaceAll(r'\', '/');
  Future<void> write(ConfinedProbe probe, String name) async {
    final result = await probe.runScript(
      'echo $name > "$out/$name.txt"; true',
      shell: brush,
    );
    if (result is ProcessCaptureNotStarted) {
      stdout.writeln('FAIL: spawn refused (${result.failure})');
      exitCode = 1;
    }
  }

  await write(base, 'before');
  final widened = SandboxSpec(
    workspaceRoot: spec.workspaceRoot,
    readableRoots: [...spec.readableRoots, outside],
    writableRoots: [...spec.writableRoots, outside],
  );
  final wide = await ConfinedProbe.tryAcquire(guard, runner, widened);
  if (wide == null) {
    stdout.writeln('FAIL: could not acquire the widened spec');
    exitCode = 1;
    return;
  }
  await write(wide, 'during');
  await guard.release(wide.sandbox);
  await guard.narrowWorkspace(
    profileName: guard.profileNameFor(spec.workspaceRoot),
    roots: [outside],
  );
  final narrowed = await ConfinedProbe.tryAcquire(guard, runner, spec);
  if (narrowed == null) {
    stdout.writeln('FAIL: could not re-acquire the base spec');
    exitCode = 1;
    return;
  }
  await write(narrowed, 'after');
  stdout.writeln('DONE');
}

/// Recreates [workspace], then acquires it again through [guard].
Future<ConfinedProbe?> _returnToRecreated(
  SandboxWindows guard,
  ProcessRunner runner,
  SandboxSpec spec,
  String workspace,
) async {
  Directory(workspace)
    ..deleteSync(recursive: true)
    ..createSync();
  return ConfinedProbe.tryAcquire(guard, runner, spec);
}

/// Reverses the shared read grant and the workspace profile so nothing
/// persists, then closes the worker isolate so this process can exit.
Future<void> _cleanup(
  SandboxWindows guard,
  String capabilitySid,
  List<String> readRoots,
  List<String> holes,
  String workspace,
) async {
  await guard.reverseWorkspace(
    profileName: guard.profileNameFor(workspace),
    workspaceRoot: workspace,
    widenedRoots: const [],
  );
  await guard.reverseSharedRead(
    capabilitySid: capabilitySid,
    readRoots: readRoots,
    holes: holes,
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
