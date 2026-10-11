import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderFailure, ProviderModelInfo, ProviderModelRef;
import 'package:provider_protocol/provider_protocol_mappers.dart';

part 'model_list.mapper.dart';

/// One model from one provider, as the palette lists it.
@model
@MappableClass()
final class ListedModel with ListedModelMappable {
  const ListedModel({
    required this.ref,
    required this.model,
    required this.providerName,
    required this.hasAccess,
  });

  final ProviderModelRef ref;

  final ProviderModelInfo model;

  final String providerName;

  /// False when the provider wants credentials the user has not given, so
  /// the model is listed but cannot run.
  final bool hasAccess;
}

/// Every model across every account, plus whichever providers could not
/// be asked.
@model
final class ModelList {
  const ModelList({required this.models, required this.failures});

  final List<ListedModel> models;

  final List<ProviderFailure> failures;
}
