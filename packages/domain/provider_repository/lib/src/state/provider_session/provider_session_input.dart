import 'package:intentions/intentions.dart';
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
