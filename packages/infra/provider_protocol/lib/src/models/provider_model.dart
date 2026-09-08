import 'package:dart_mappable/dart_mappable.dart';
import 'package:provider_protocol/src/models/provider_reasoning.dart';

part 'provider_model.mapper.dart';

/// A model in the provider's catalog.
@MappableClass()
final class ProviderModel with ProviderModelMappable {
  const ProviderModel({
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
