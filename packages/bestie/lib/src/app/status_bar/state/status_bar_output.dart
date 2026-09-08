import 'package:intentions/intentions.dart';

@model
sealed class StatusBarOutput {
  const StatusBarOutput();
}

@model
final class StatusBarStateUpdated extends StatusBarOutput {
  const StatusBarStateUpdated();
}

/// The balance is likely stale: the provider just came up or a turn just
/// spent something.
@model
final class RefreshCreditsRequested extends StatusBarOutput {
  const RefreshCreditsRequested();
}

/// The sandbox let go of [count] granted write directories at the user's
/// request.
@model
final class SandboxForgotWriteGrants extends StatusBarOutput {
  const SandboxForgotWriteGrants(this.count);

  final int count;
}

/// The sandbox finished its startup after the user had been shown the wait.
@model
final class SandboxBecameReady extends StatusBarOutput {
  const SandboxBecameReady();
}
