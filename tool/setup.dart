// Full fresh-clone setup: submodules, deps, native assets, sidecars, codegen.
// Replaces the fragile `&&`-chain in the `setup` melos script with a
// host-aware orchestrator so a single `dart run melos run setup` works on
// Windows, macOS and Linux alike.
//
// Usage:
//   dart run melos run setup      # or: dart tool/setup.dart
//
// Materializing the coreutils dispatch links is deliberately NOT here: bestie's
// bootstrap does it idempotently on first run (detect the links, make them if
// absent), so the staged `bin/` fills in the first time bestie runs.
import 'dart:io';

import 'src/helpers.dart';

Future<void> main() async {
  final steps = _setupSteps();
  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    final ordinal = '[${i + 1}/${steps.length}]';

    if (step.skipOnHost) {
      stdout.writeln('$ordinal skip: ${step.name} (${step.skipReason})');
      continue;
    }

    stdout.writeln('\n$ordinal ${step.name}');
    stdout.writeln('    ${step.executable} ${step.arguments.join(' ')}');
    final code = await runCommand(step.executable, step.arguments);
    if (code != 0) {
      stderr.writeln('\nsetup failed at "${step.name}" (exit $code).');
      exitCode = code;
      return;
    }
  }
  stdout.writeln('\nsetup complete.');
}

/// The ordered setup pipeline for the current host.
List<SetupStep> _setupSteps() {
  return [
    SetupStep(
      name: 'submodules',
      executable: 'git',
      arguments: const ['submodule', 'update', '--init', '--recursive'],
    ),
    SetupStep(
      name: 'workspace dependencies',
      executable: 'dart',
      arguments: const ['pub', 'get'],
    ),
    SetupStep(
      name: 'curl-impersonate assets',
      executable: 'dart',
      // The macOS and Linux archives carry symlinked libraries Windows `tar`
      // cannot extract, so a Windows host must ask for only its own build.
      arguments: [
        'tool/download_curl_assets.dart',
        if (Platform.isWindows) ...['--os', 'windows'],
      ],
    ),
    SetupStep(
      name: 'CA certificate bundle',
      executable: 'dart',
      arguments: const ['tool/download_cert_assets.dart'],
    ),
    SetupStep(
      name: 'Windows console host',
      executable: 'dart',
      arguments: const ['tool/download_openconsole_assets.dart'],
      // ConPTY is a Windows API
      skipOnHost: !Platform.isWindows,
      skipReason: 'Windows-only',
    ),
    SetupStep(
      name: 'spawner PTY helper',
      executable: 'dart',
      arguments: const ['tool/build_spawner.dart'],
      // The spawner is a POSIX-only PTY helper; Windows spawns via ConPTY and
      // needs no native helper.
      skipOnHost: Platform.isWindows,
      skipReason: 'POSIX-only',
    ),
    SetupStep(
      name: 'Rust sidecars (shell userland + editor)',
      executable: 'dart',
      arguments: const ['tool/build_sidecar.dart', '--all'],
    ),
    SetupStep(
      name: 'code generation',
      executable: 'dart',
      arguments: const ['run', 'melos', 'run', 'codegen', '--no-select'],
    ),
  ];
}

/// One step of the setup pipeline.
class SetupStep {
  const SetupStep({
    required this.name,
    required this.executable,
    required this.arguments,
    this.skipOnHost = false,
    this.skipReason = '',
  });

  /// Human-readable step label.
  final String name;

  /// Command to run.
  final String executable;

  /// Command arguments.
  final List<String> arguments;

  /// Whether this step does not apply to the current host.
  final bool skipOnHost;

  /// Why the step is skipped, shown when [skipOnHost] is set.
  final String skipReason;
}
