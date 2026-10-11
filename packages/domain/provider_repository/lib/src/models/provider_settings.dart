import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderCredentials, ProviderModelRef;

/// What the user asked to run against: the credentials for each provider
/// they set up, which model, how many agents at once, and how much context
/// to load it with.
@model
@immutable
final class ProviderSettings {
  const ProviderSettings({
    required this.credentials,
    required this.model,
    required this.maxAgents,
    this.contextCap,
  });

  /// Keyed by provider id. A provider left out runs without credentials.
  final Map<String, ProviderCredentials> credentials;

  final ProviderModelRef? model;

  final int maxAgents;

  /// The most context to run the model with, for providers that load
  /// models; null for as much as fits.
  final int? contextCap;

  /// Whether there is enough here to attempt a connection.
  bool get isComplete => model != null && maxAgents > 0;

  /// Whether [other] runs the same credentials, model, and agents, so that
  /// a session running these need not be rebuilt for it. The context cap is
  /// read when a model is loaded, so it alone may differ.
  bool runsSameSessionAs(ProviderSettings other) =>
      other.model == model &&
      other.maxAgents == maxAgents &&
      other.credentials.length == credentials.length &&
      credentials.entries.every(
        (entry) => other.credentials[entry.key] == entry.value,
      );

  @override
  bool operator ==(Object other) =>
      other is ProviderSettings &&
      other.contextCap == contextCap &&
      runsSameSessionAs(other);

  @override
  int get hashCode => Object.hash(
    model,
    maxAgents,
    contextCap,
    Object.hashAllUnordered(
      credentials.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );

  /// Never prints a key.
  @override
  String toString() =>
      'ProviderSettings(model: ${model?.qualified}, maxAgents: $maxAgents, '
      'contextCap: $contextCap, credentials: $credentials)';
}
