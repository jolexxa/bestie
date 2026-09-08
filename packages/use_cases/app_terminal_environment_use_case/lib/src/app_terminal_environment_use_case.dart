import 'dart:async';
import 'dart:io';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:platform_repository/platform_repository.dart';

/// Owns how bestie reaches into the host terminal for the life of a run —
/// orchestrated over the [OSPlatformRepository].
@useCase
class AppTerminalEnvironmentUseCase implements CommandContribution {
  AppTerminalEnvironmentUseCase({
    required OSPlatformRepository platformRepository,
    IOSink? stdoutSink,
    IOSink? stderrSink,
    void Function(int code)? exitProcess,
  }) : _platform = platformRepository,
       _stdout = stdoutSink ?? stdout,
       _stderr = stderrSink ?? stderr,
       _exit = exitProcess ?? exit {
    commands = List.unmodifiable([
      Command(
        id: 'app.recaptureInput',
        title: 'Recapture terminal input',
        glyph: '⌨',
        description: 'Re-enable mouse and keyboard reporting',
        group: 'App',
        availability: alwaysAvailable(),
        invoke: _recaptureInvoke,
      ),
      Command(
        id: 'app.quit',
        title: 'Quit',
        glyph: '✕',
        shortcut: 'Ctrl+C',
        description: 'Exit the app',
        group: 'App',
        availability: alwaysAvailable(),
        invoke: _quitInvoke,
      ),
    ]);
  }

  @override
  late final List<Command> commands;

  final OSPlatformRepository _platform;
  final IOSink _stdout;
  final IOSink _stderr;
  final void Function(int code) _exit;

  final List<TerminalOverride> _overrides = [];

  final _exitController = StreamController<int>.broadcast();

  /// Emits the requested exit code each time [quit] is called.
  Stream<int> get exitRequested => _exitController.stream;

  /// Requests that the app exit with [code].
  void quit([int code = 0]) => _exitController.add(code);

  /// The keys bestie needs as raw bytes: control keys (so the shell sees `^C`)
  /// and editing keys (so `^O` / `^V` / `^R` are not swallowed by the line
  /// driver).
  static const Set<InputCapture> _capturedKeys = {
    InputCapture.controlKeys,
    InputCapture.editingKeys,
  };

  /// Redirects native stderr to [nativeLogPath] (so FFI noise never
  /// reaches the TUI), pushes [title] onto the terminal's title stack, and
  /// captures [_capturedKeys].
  void activate({required String nativeLogPath, required String title}) {
    _remember(_platform.redirectStderr(targetPath: nativeLogPath));
    _remember(_platform.setWindowTitle(title));
    _remember(_platform.captureInput(_capturedKeys));
  }

  /// Re-asserts input capture.
  void reassertInputCapture() => _platform.captureInput(_capturedKeys);

  void _remember(TerminalOverride? override) {
    if (override != null) _overrides.add(override);
  }

  /// Reverts every applied override in reverse order.
  Future<void> restore() async {
    for (final override in _overrides.reversed) {
      await override.revert();
    }
    _overrides.clear();
  }

  /// Flushes stdout and stderr, then ends the process with [status].
  Future<void> flushThenExit(int status) async {
    await Future.wait<void>([_stdout.close(), _stderr.close()]);
    _exit(status);
  }

  Future<CommandResult> _recaptureInvoke(Answers answers) async {
    reassertInputCapture();
    return const CommandRan();
  }

  Future<CommandResult> _quitInvoke(Answers answers) async {
    quit();
    return const CommandRan();
  }

  Future<void> dispose() async => _exitController.close();
}
