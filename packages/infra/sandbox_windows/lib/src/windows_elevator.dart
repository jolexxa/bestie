import 'package:win32_dart/win32_dart.dart';

/// Runs a program elevated and waits for it.
// ignore: one_member_abstracts
abstract interface class WindowsElevator {
  /// Runs [executable] with [arguments] elevated and waits for it to exit.
  ElevatedRunOutcome run({
    required String executable,
    required List<String> arguments,
  });
}

/// What came of running a program elevated.
sealed class ElevatedRunOutcome {
  const ElevatedRunOutcome();
}

/// It ran and ended with [exitCode].
final class ElevatedRunCompleted extends ElevatedRunOutcome {
  /// Wraps the [exitCode].
  const ElevatedRunCompleted(this.exitCode);

  /// The program's exit code.
  final int exitCode;
}

/// The user said no at the prompt.
final class ElevatedRunDeclined extends ElevatedRunOutcome {
  /// Const so it composes once.
  const ElevatedRunDeclined();
}

/// It could not be started or waited on, for [reason].
final class ElevatedRunFailed extends ElevatedRunOutcome {
  /// Wraps the failure [reason].
  const ElevatedRunFailed(this.reason);

  /// Why it could not run.
  final String reason;
}

/// The real [WindowsElevator], over win32_dart.
class Win32Elevator implements WindowsElevator {
  /// Calls through [bindings] (the real host by default).
  Win32Elevator({WindowsBindings? bindings}) : _bindings = bindings ?? win32;

  final WindowsBindings _bindings;

  @override
  ElevatedRunOutcome run({
    required String executable,
    required List<String> arguments,
  }) => switch (Elevations(
    _bindings,
  ).run(executable: executable, arguments: arguments)) {
    ElevationCompleted(:final exitCode) => ElevatedRunCompleted(exitCode),
    ElevationDeclined() => const ElevatedRunDeclined(),
    ElevationFailed(:final failure) => ElevatedRunFailed(failure.toString()),
  };
}
