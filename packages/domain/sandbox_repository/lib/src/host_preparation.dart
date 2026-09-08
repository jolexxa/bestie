import 'package:intentions/intentions.dart';

/// Whether the host's one-time grants were put in place.
@model
sealed class HostPreparation {
  const HostPreparation();
}

/// Every grant is in place.
@model
final class HostPrepared extends HostPreparation {
  const HostPrepared();
}

/// The user declined the approval; nothing changed.
@model
final class HostPreparationDeclined extends HostPreparation {
  const HostPreparationDeclined();
}

/// A grant could not be put in place, for [reason].
@model
final class HostPreparationFailed extends HostPreparation {
  const HostPreparationFailed(this.reason);

  final String reason;
}
