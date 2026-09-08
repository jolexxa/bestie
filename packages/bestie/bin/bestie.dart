import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:app_terminal_environment_use_case/app_terminal_environment_use_case.dart';
import 'package:bestie/src/app/app.dart';
import 'package:bestie/src/app/app_context.dart';
import 'package:bestie/src/app/assets/app_assets.dart';
import 'package:bestie/src/app/models/app_metadata.dart';
import 'package:bestie_platform_linux/bestie_platform_linux.dart';
import 'package:bestie_platform_macos/bestie_platform_macos.dart';
import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:bestie_posix/bestie_posix.dart';
import 'package:diagnostics/diagnostics.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:file/local.dart' show LocalFileSystem;
import 'package:io/io.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform/platform.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox_windows/sandbox_windows.dart'
    show SandboxAncestorGrant, grantSandboxAncestorsFlag;

/// True in a compiled release bundle (AOT product), false when running from
/// source via `dart run`. Drives bundle-vs-source native-asset resolution.
const kReleaseMode = bool.fromEnvironment('dart.vm.product');

Future<void> main(List<String> args) async {
  const fileSystem = LocalFileSystem();
  const hostPlatform = LocalPlatform();
  final abi = Abi.current();

  // Helper mode: grant the ancestors and exit without starting the app.
  if (hostPlatform.isWindows && args.firstOrNull == grantSandboxAncestorsFlag) {
    exit(
      SandboxAncestorGrant(
        capabilitySid: SandboxAncestorGrant.derivedCapabilitySid(),
      ).run(args.skip(1).toList()),
    );
  }

  // The platform facade the terminal-env use case orchestrates and the app
  // graph holds. Cheap to build, so it comes up before anything touches disk.
  final platformRepository = composePlatformRepository(
    platform: hostPlatform,
    fileSystem: fileSystem,
    abi: abi,
    bundled: kReleaseMode,
  );
  final platform = platformRepository.platform;

  // Foundational logging. Creating the logs dir also creates `~/.bestie`. Both
  // sinks live in `$HOME/.bestie/logs/`, truncated on each run, so a post-crash
  // `tail` always has the last run's output:
  //   - native.log  — fd 2 capture (native panics, FFI asserts), applied by
  //     the terminal-env use case below.
  //   - managed.log — Diagnostics breadcrumbs (sync writes that survive
  //     segfaults / hard exits bypassing dispose chains).
  fileSystem.directory(platform.logsDir).createSync(recursive: true);
  Diagnostics.init(platform.managedLogFile);

  NoctermError.onError = (details) {
    Diagnostics.log('nocterm.error', details.toString().trim());
    NoctermError.dumpErrorToConsole(details);
  };

  // Take over the terminal before the heavy native build, so load-time
  // stderr from native libraries is already redirected into native.log.
  final terminalEnvironmentUseCase =
      AppTerminalEnvironmentUseCase(platformRepository: platformRepository)
        ..activate(
          nativeLogPath: platform.nativeLogFile,
          title: AppMetadata.title,
        );

  final context = await AppContext.initialize(
    hostPlatform: hostPlatform,
    fileSystem: fileSystem,
    abi: abi,
    bundled: kReleaseMode,
    platformRepository: platformRepository,
    appTerminalEnvironmentUseCase: terminalEnvironmentUseCase,
  );

  await context.start();

  final crashLog = File(platform.crashLogFile);
  Object? fatalError;
  int? code;
  try {
    code = await runZonedGuarded<Future<int>>(
      () async {
        await runBestieApp(context);
        return ExitCode.success.code;
      },
      (error, stack) {
        fatalError = error;
        _recordCrash(crashLog, error, stack);
        TerminalBinding.instance.requestShutdown(ExitCode.software.code);
      },
    );
  } finally {
    // Disposal tears down the graph and restores the terminal overrides last.
    await context.dispose();
  }

  if (fatalError != null) {
    stdout
      ..writeln('bestie crashed: $fatalError')
      ..writeln('Stack trace: ${crashLog.path}');
  }

  await terminalEnvironmentUseCase.flushThenExit(
    code ?? ExitCode.software.code,
  );
}

/// Builds the platform facade.
OSPlatformRepository composePlatformRepository({
  required Platform platform,
  required FileSystem fileSystem,
  required Abi abi,
  required bool bundled,
}) {
  if (platform.isMacOS) {
    final dataSource = MacOSPlatformDataSource(
      platform: platform,
      fileSystem: fileSystem,
      abi: abi,
      bundled: bundled,
      assets: macOSAppAssets,
    );
    final osPlatform = dataSource.loadPlatform();
    final processHost = PosixProcessHost(
      spawnerBinaryPath: dataSource.resolveSpawnerPath(),
    );
    return OSPlatformRepository(
      platform: osPlatform,
      systemInfoDataSource: MacOSSystemInfoDataSource(),
      clipboardDataSource: MacOSClipboardDataSource(
        runner: ProcessRunner(
          host: processHost,
          environment: platform.environment,
        ),
      ),
      diskSpaceDataSource: MacOSDiskSpaceDataSource(),
      terminalEnvironmentDataSource: BestiePosixDataSource(
        platform: osPlatform,
      ),
    );
  } else if (platform.isLinux) {
    final dataSource = LinuxPlatformDataSource(
      platform: platform,
      fileSystem: fileSystem,
      abi: abi,
      bundled: bundled,
      assets: linuxAppAssets,
    );
    final osPlatform = dataSource.loadPlatform();
    final processHost = PosixProcessHost(
      spawnerBinaryPath: dataSource.resolveSpawnerPath(),
    );
    return OSPlatformRepository(
      platform: osPlatform,
      systemInfoDataSource: LinuxSystemInfoDataSource(),
      clipboardDataSource: LinuxClipboardDataSource(
        platform: platform,
        runner: ProcessRunner(
          host: processHost,
          environment: platform.environment,
        ),
      ),
      diskSpaceDataSource: LinuxDiskSpaceDataSource(),
      terminalEnvironmentDataSource: BestiePosixDataSource(
        platform: osPlatform,
      ),
    );
  } else if (platform.isWindows) {
    final dataSource = WindowsPlatformDataSource(
      platform: platform,
      fileSystem: fileSystem,
      abi: abi,
      bundled: bundled,
      assets: windowsAppAssets,
    );
    final osPlatform = dataSource.loadPlatform();
    return OSPlatformRepository(
      platform: osPlatform,
      systemInfoDataSource: WindowsSystemInfoDataSource(),
      clipboardDataSource: WindowsClipboardDataSource(),
      diskSpaceDataSource: WindowsDiskSpaceDataSource(),
      terminalEnvironmentDataSource: WindowsTerminalDataSource(),
    );
  }

  throw UnsupportedError('Unsupported platform: ${platform.operatingSystem}');
}

/// Appends the crash to a durable log.
void _recordCrash(File crashLog, Object error, StackTrace stack) {
  try {
    crashLog
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '--- ${DateTime.now().toIso8601String()}\n$error\n$stack\n',
        mode: FileMode.append,
      );
  } on Object {
    // There is nowhere left to report.
  }
}
