import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderModelRef, ProviderReasoning;
import 'package:provider_protocol/provider_protocol_mappers.dart';

part 'resolved_model.mapper.dart';

/// The model the session runs, with every fact an agent needs settled.
@model
@MappableClass()
final class ResolvedModel with ResolvedModelMappable {
  const ResolvedModel({
    required this.ref,
    required this.name,
    required this.contextWindow,
    required this.supportsTools,
    this.reasoning,
  });

  final ProviderModelRef ref;

  final String name;

  final int contextWindow;

  final bool supportsTools;

  /// How the model thinks; null when it cannot.
  final ProviderReasoning? reasoning;

  String get id => ref.modelId;
}
