import 'package:meta/meta.dart';

/// How a supervised child process terminated.
@immutable
sealed class ProcessExit {
  const ProcessExit();
}

/// The child called `exit(code)` / returned normally.
final class ProcessExited extends ProcessExit {
  /// Wraps a normal-exit [code].
  const ProcessExited(this.code);

  /// The exit code, 0–255 on POSIX.
  final int code;

  @override
  bool operator ==(Object other) =>
      other is ProcessExited && other.code == code;

  @override
  int get hashCode => Object.hash('ProcessExited', code);

  @override
  String toString() => 'ProcessExited($code)';
}

/// The child was terminated by an unhandled signal. POSIX only —
/// Windows has no signals and never reports this.
final class ProcessSignaled extends ProcessExit {
  /// Wraps the terminating [signal].
  const ProcessSignaled(this.signal);

  /// The terminating signal (`WTERMSIG`).
  final int signal;

  @override
  bool operator ==(Object other) =>
      other is ProcessSignaled && other.signal == signal;

  @override
  int get hashCode => Object.hash('ProcessSignaled', signal);

  @override
  String toString() => 'ProcessSignaled($signal)';
}

/// The child reported a status we don't decode (e.g. stopped /
/// continued). We know it reported *something*, just not a clean exit
/// or signal.
final class ProcessUnknown extends ProcessExit {
  /// An undecodable-but-reported status.
  const ProcessUnknown();

  @override
  bool operator ==(Object other) => other is ProcessUnknown;

  @override
  int get hashCode => 'ProcessUnknown'.hashCode;

  @override
  String toString() => 'ProcessUnknown()';
}

/// The supervisor died without reporting a status (fork failure, crash
/// → status channel EOF).
final class ProcessSupervisorLost extends ProcessExit {
  /// No status was ever reported.
  const ProcessSupervisorLost();

  @override
  bool operator ==(Object other) => other is ProcessSupervisorLost;

  @override
  int get hashCode => 'ProcessSupervisorLost'.hashCode;

  @override
  String toString() => 'ProcessSupervisorLost()';
}
