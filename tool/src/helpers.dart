import 'dart:io';

/// Returns the repository root directory.
Directory repoRoot() {
  return File.fromUri(Platform.script).parent.parent;
}

/// Runs a command with inherited stdio (live output).
Future<int> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

/// Staging root for the shell userland binaries: the `agent_shell` package's
/// native-asset directory for the current host, under a `shell` subdir.
/// `cargo install --root` writes the binary to `<stageRoot>/bin/<exe>`, so this
/// yields `.../native/<os>/<arch>/shell/bin/<exe>` — the `shell/bin` layout the
/// platform data sources resolve (and release.yaml stages into `lib/shell/bin`).
String shellStageRoot(String repoRootPath) {
  const assets = 'packages/infra/agent_shell/assets/native';
  return '$repoRootPath/$assets/${hostAssetSubdir()}/shell';
}

/// The `<platform>/<arch>` subdirectory for the current host, matching the
/// layout `AppAssetResolver` searches (`assets/native/<os>/<arch>/`) and the
/// CI release matrix: `macos/arm64`, `linux/x64`, `windows/x64`.
String hostAssetSubdir() {
  if (Platform.isWindows) return 'windows/x64';
  if (Platform.isMacOS) return 'macos/${_uname('-m')}';
  if (Platform.isLinux) {
    final m = _uname('-m');
    return 'linux/${m == 'x86_64' ? 'x64' : m}';
  }
  throw UnsupportedError('native builds support Windows / macOS / Linux only');
}

/// One repo-local cargo target directory shared by every Rust build, so a
/// CI cache keyed on it covers all of them and dependencies compile once.
String cargoTargetDir(String repoRootPath) =>
    '$repoRootPath/build/cargo-target';

/// Windows builds target msvc with a static CRT so the binaries carry no
/// VC++ redistributable dependency.
const windowsRustTarget = 'x86_64-pc-windows-msvc';

List<String> get _targetArgs => [
  if (Platform.isWindows) ...['--target', windowsRustTarget],
];

Map<String, String> get _cargoEnvironment => {
  if (Platform.isWindows) 'RUSTFLAGS': '-C target-feature=+crt-static',
};

/// `cargo install`s a crate from crates.io into [stageRoot]/bin. [featureArgs]
/// carries crate-specific feature selection (empty = the crate's default
/// features).
Future<int> cargoInstallCrate({
  required String crate,
  required String version,
  required String stageRoot,
  required String targetDir,
  List<String> featureArgs = const [],
}) => runCommand('cargo', [
  'install',
  crate,
  '--version',
  version,
  '--locked',
  '--force',
  '--root',
  stageRoot,
  '--target-dir',
  targetDir,
  ...featureArgs,
  ..._targetArgs,
], environment: _cargoEnvironment);

/// `cargo build --release`s the crate at [crateDir] into [targetDir], and
/// returns the directory the release binaries land in. [locked] holds the
/// build to the crate's committed `Cargo.lock`.
Future<String?> cargoBuildRelease({
  required String crateDir,
  required String targetDir,
  bool locked = false,
}) async {
  final code = await runCommand(
    'cargo',
    [
      'build',
      '--release',
      if (locked) '--locked',
      '--target-dir',
      targetDir,
      ..._targetArgs,
    ],
    workingDirectory: crateDir,
    environment: _cargoEnvironment,
  );
  if (code != 0) return null;
  return Platform.isWindows
      ? '$targetDir/$windowsRustTarget/release'
      : '$targetDir/release';
}

String _uname(String flag) {
  final r = Process.runSync('uname', [flag]);
  return (r.stdout as String).trim();
}
