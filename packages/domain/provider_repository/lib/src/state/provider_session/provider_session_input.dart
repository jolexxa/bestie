import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderModelLoadProgress, ProviderModelLoadResult;
import 'package:provider_repository/src/models/provider_settings.dart';
import 'package:provider_repository/src/state/provider_session/model_resolution.dart';

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

/// Stop running the chosen model until the settings change or a reconnect.
@model
final class StopProvider extends ProviderSessionInput {
  const StopProvider();
}

/// Looking up the chosen model, started under [attempt], finished.
@model
final class ModelResolved extends ProviderSessionInput {
  const ModelResolved({required this.attempt, required this.resolution});

  final int attempt;
  final ModelResolution resolution;
}

/// The model loading under [attempt] got further.
@model
final class LoadProgressed extends ProviderSessionInput {
  const LoadProgressed({required this.attempt, required this.progress});

  final int attempt;
  final ProviderModelLoadProgress progress;
}

/// The load started under [attempt] ended.
@model
final class LoadCompleted extends ProviderSessionInput {
  const LoadCompleted({required this.attempt, required this.result});

  final int attempt;
  final ProviderModelLoadResult result;
}

/// The model loaded under [attempt] is no longer served.
@model
final class ModelLost extends ProviderSessionInput {
  const ModelLost({required this.attempt});

  final int attempt;
}

/// The wait before loading a lost model again, started under [attempt], is
/// over.
@model
final class RecoveryDue extends ProviderSessionInput {
  const RecoveryDue({required this.attempt});

  final int attempt;
}
