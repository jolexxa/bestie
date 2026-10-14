import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderModelRef;

/// What the user asked to run: which model, and how many agents at once.
@model
@immutable
final class ProviderSettings {
  const ProviderSettings({required this.model, required this.maxAgents});

  final ProviderModelRef? model;

  final int maxAgents;

  /// Whether there is enough here to attempt a connection.
  bool get isComplete => model != null && maxAgents > 0;

  @override
  bool operator ==(Object other) =>
      other is ProviderSettings &&
      other.model == model &&
      other.maxAgents == maxAgents;

  @override
  int get hashCode => Object.hash(model, maxAgents);

  @override
  String toString() =>
      'ProviderSettings(model: ${model?.qualified}, maxAgents: $maxAgents)';
}
