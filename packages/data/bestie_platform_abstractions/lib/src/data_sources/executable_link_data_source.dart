import 'package:intentions/intentions.dart';

/// Creates a filesystem link so a name on `PATH` dispatches to a single
/// multicall executable — a hardlink on Windows, a symlink on POSIX.
@dataSource
// This is a platform abstraction interface, not a utility function.
// ignore: one_member_abstracts
abstract interface class ExecutableLinkDataSource {
  /// Links [linkPath] to the existing [targetPath].
  ExecutableLinkResult link({
    required String linkPath,
    required String targetPath,
  });
}

/// Outcome of an [ExecutableLinkDataSource.link] call.
sealed class ExecutableLinkResult {
  const ExecutableLinkResult();
}

/// The link now exists at the requested path.
@model
final class ExecutableLinkCreated extends ExecutableLinkResult {
  const ExecutableLinkCreated();
}

/// The link could not be created; [reason] describes why.
@model
final class ExecutableLinkFailed extends ExecutableLinkResult {
  const ExecutableLinkFailed(this.reason);

  /// Human-readable failure description, already platform-neutral.
  final String reason;
}
