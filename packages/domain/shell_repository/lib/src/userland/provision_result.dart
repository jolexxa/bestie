import 'package:intentions/intentions.dart';

/// Outcome of asking the userland repository to materialize its dispatch links.
@model
sealed class ProvisionResult {
  const ProvisionResult();
}

/// Links were materialized; [linkedNames] are the utilities linked.
@model
final class ProvisionSucceeded extends ProvisionResult {
  const ProvisionSucceeded(this.linkedNames);

  /// Names of the utilities linked next to the multicall.
  final List<String> linkedNames;
}

/// A prior run already provisioned this exact multicall; nothing to do.
@model
final class ProvisionUpToDate extends ProvisionResult {
  const ProvisionUpToDate();
}

/// Provisioning stopped; [reason] describes what went wrong.
@model
final class ProvisionFailed extends ProvisionResult {
  const ProvisionFailed(this.reason);

  /// Human-readable failure description.
  final String reason;
}
