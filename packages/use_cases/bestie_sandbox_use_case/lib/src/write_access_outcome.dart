import 'package:intentions/intentions.dart';

/// What came of an agent asking to write under a directory.
@model
sealed class WriteAccessOutcome {
  const WriteAccessOutcome(this.path);

  /// The directory asked for, normalized and absolute.
  final String path;
}

/// The user allowed it: the grant is saved and the next program runs under it.
@model
final class WriteAccessGranted extends WriteAccessOutcome {
  const WriteAccessGranted(super.path);
}

/// The user refused, now or earlier this session.
@model
final class WriteAccessDeclined extends WriteAccessOutcome {
  const WriteAccessDeclined(super.path);
}

/// Nothing to ask: the sandbox is off or already lets programs write there.
@model
final class WriteAccessAlreadyAllowed extends WriteAccessOutcome {
  const WriteAccessAlreadyAllowed(super.path);
}

/// Never put to the user: the directory is not one the sandbox will open.
@model
final class WriteAccessRefused extends WriteAccessOutcome {
  const WriteAccessRefused(super.path, this.reason);

  final String reason;
}

/// The user allowed it and the grant is saved, but the sandbox could not be
/// rebuilt around it now.
@model
final class WriteAccessFailed extends WriteAccessOutcome {
  const WriteAccessFailed(super.path, this.reason);

  final String reason;
}
