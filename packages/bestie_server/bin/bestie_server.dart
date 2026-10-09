import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math' as math;

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_server/bestie_server.dart';
import 'package:file/local.dart';
import 'package:inference_llama/inference_llama.dart';
import 'package:inference_server/inference_server.dart';
import 'package:path/path.dart' as p;

const _serverVersion = '0.0.0';
const _bundled = bool.fromEnvironment('dart.vm.product');

const _llamaLibraries = AppAsset(
  path: '',
  missingMessage:
      'The llama.cpp libraries are missing. Run '
      '`dart tool/download_llama_assets.dart`.',
  packageOwner: 'packages/ffi/llama_cpp_dart',
  bundleUnit: AssetBundleUnit.ownerNativeDir,
);

Future<void> main(List<String> arguments) async {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  switch (ServerArguments.parse(arguments, home: home)) {
    case ServerArgumentsHelp():
      stdout.writeln(ServerArguments.usage);
    case ServerArgumentsInvalid(:final message):
      stderr
        ..writeln(message)
        ..writeln(ServerArguments.usage);
      exitCode = 64;
    case ServerArgumentsParsed(arguments: final parsed):
      exit(await _run(parsed));
  }
}

Future<int> _run(ServerArguments arguments) async {
  final logPath = arguments.logPath;
  final sink = logPath == null
      ? stderr
      : File(logPath).openWrite(mode: FileMode.append);
  final log = SinkServerLog(sink);

  final stopped = await ServerLaunch(
    bestieDir: arguments.bestieDir,
    engineStarter: IsolatedEngineStarter(
      LlamaEngineStarter(
        libraries: _llamaLibrariesIn(_libraryDir()),
        threads: math.max(1, Platform.numberOfProcessors ~/ 2),
      ),
    ),
    log: log,
    fileSystem: const LocalFileSystem(),
    serverVersion: _serverVersion,
    pid: pid,
    shutdownRequests: _shutdownSignals(),
  ).run();
  await sink.flush();
  if (logPath != null) await sink.close();
  return stopped.exitCode;
}

String _libraryDir() {
  final resolver = AppAssetResolver(
    bundled: _bundled,
    fileSystem: const LocalFileSystem(),
    executableDir: p.dirname(Platform.resolvedExecutable),
    repoRoot: p.normalize(
      p.join(p.dirname(Platform.script.toFilePath()), '..', '..', '..'),
    ),
    platformDir: switch (Platform.operatingSystem) {
      'macos' => 'macos',
      'windows' => 'windows',
      _ => 'linux',
    },
    archDir: switch (Abi.current()) {
      Abi.macosArm64 || Abi.linuxArm64 || Abi.windowsArm64 => 'arm64',
      _ => 'x64',
    },
  );
  return resolver.resolve(_llamaLibraries);
}

LlamaBackendLibraries _llamaLibrariesIn(String directory) {
  String library(String name) =>
      p.join(directory, switch (Platform.operatingSystem) {
        'macos' => 'lib$name.dylib',
        'windows' => '$name.dll',
        _ => 'lib$name.so',
      });
  return LlamaBackendLibraries(
    runtimeLibraryPath: library('llama'),
    commonLibraryPath: library('llama-common'),
    additionalSymbolLibraryPlatformPaths: Platform.isWindows
        ? [library('ggml'), library('ggml-base')]
        : const [],
  );
}

/// SIGINT, and SIGTERM where it exists, watched only while listened to so an
/// unheard watch never keeps the process alive.
Stream<void> _shutdownSignals() {
  final signals = [
    ProcessSignal.sigint,
    if (!Platform.isWindows) ProcessSignal.sigterm,
  ];
  final watches = <StreamSubscription<ProcessSignal>>[];
  late final StreamController<void> requests;
  requests = StreamController<void>(
    onListen: () {
      for (final signal in signals) {
        watches.add(signal.watch().listen((_) => requests.add(null)));
      }
    },
    onCancel: () => Future.wait([for (final watch in watches) watch.cancel()]),
  );
  return requests.stream;
}
