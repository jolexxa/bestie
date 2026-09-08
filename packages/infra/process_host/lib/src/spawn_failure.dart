import 'package:meta/meta.dart';

/// Why a spawn never got off the ground, in terms every platform can
/// express: the native call that refused, its error code, and a
/// human-readable message.
@immutable
final class SpawnFailure {
  /// Describes a [function] that refused with [message], optionally
  /// carrying the platform's numeric error [code].
  const SpawnFailure({
    required this.function,
    required this.message,
    this.code = 0,
  });

  /// Name of the native call that refused, e.g. `posix_spawnp`.
  final String function;

  /// Human-readable description of the failure.
  final String message;

  /// The platform error code — `errno` on POSIX, `GetLastError` on
  /// Windows. Zero when the call reported no code.
  final int code;

  @override
  bool operator ==(Object other) =>
      other is SpawnFailure &&
      other.function == function &&
      other.message == message &&
      other.code == code;

  @override
  int get hashCode => Object.hash(function, message, code);

  @override
  String toString() => code == 0
      ? 'SpawnFailure($function): $message'
      : 'SpawnFailure($function, code=$code): $message';
}
