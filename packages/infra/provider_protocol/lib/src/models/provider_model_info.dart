import 'package:dart_mappable/dart_mappable.dart';
import 'package:provider_protocol/src/models/provider_reasoning.dart';

part 'provider_model_info.mapper.dart';

/// A model a provider lists, with every fact an agent needs to run it.
@MappableClass()
final class ProviderModelInfo with ProviderModelInfoMappable {
  const ProviderModelInfo({
    required this.id,
    required this.name,
    required this.supportsTools,
    this.contextLength,
    this.reasoning,
    this.promptPricePerToken,
    this.completionPricePerToken,
  });

  final String id;

  final String name;

  /// Tokens the model can attend to, when the provider says.
  final int? contextLength;

  final bool supportsTools;

  /// How the model thinks; null when it cannot.
  final ProviderReasoning? reasoning;

  final double? promptPricePerToken;

  final double? completionPricePerToken;
}
