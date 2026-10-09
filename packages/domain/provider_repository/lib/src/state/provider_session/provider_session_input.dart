import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ModelActivationResult;
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/state/provider_session/provider_probe.dart';

@model
sealed class ProviderSessionInput {
  const ProviderSessionInput();
}

/// The user's settings changed.
@model
final class ConfigureProvider extends ProviderSessionInput {
  const ConfigureProvider(this.settings);

  final ProviderSettings settings;
}

/// Try the current settings again.
@model
final class ReconnectProvider extends ProviderSessionInput {
  const ReconnectProvider();
}

/// A probe started under [attempt] finished.
@model
final class ProbeCompleted extends ProviderSessionInput {
  const ProbeCompleted({required this.attempt, required this.outcome});

  final int attempt;
  final ProbeOutcome outcome;
}

/// The model activated under [attempt] is [progress] of the way ready.
@model
final class ActivationProgressed extends ProviderSessionInput {
  const ActivationProgressed({required this.attempt, required this.progress});

  final int attempt;

  /// From 0 to 1.
  final double progress;
}

/// The activation started under [attempt] ended.
@model
final class ActivationCompleted extends ProviderSessionInput {
  const ActivationCompleted({required this.attempt, required this.result});

  final int attempt;
  final ModelActivationResult result;
}

/// The model activated under [attempt] is no longer served.
@model
final class ActivationLost extends ProviderSessionInput {
  const ActivationLost({required this.attempt});

  final int attempt;
}

/// The wait before activating a lost model again, started under [attempt],
/// is over.
@model
final class RecoveryDue extends ProviderSessionInput {
  const RecoveryDue({required this.attempt});

  final int attempt;
}

/// The provider [providerId] would now list different models.
@model
final class ModelsChanged extends ProviderSessionInput {
  const ModelsChanged(this.providerId);

  final String providerId;
}

/// Stop running the chosen model until the settings change or a reconnect.
@model
final class StopProvider extends ProviderSessionInput {
  const StopProvider();
}
