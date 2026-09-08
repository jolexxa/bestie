import 'package:provider_protocol/provider_protocol.dart';

/// The catalog's models for [descriptor]; empty when it lists none or
/// cannot be reached, since the live endpoint is the authority anyway.
Future<List<ProviderModel>> knownModels(
  ModelCatalog catalog,
  ProviderDescriptor descriptor,
) async {
  final catalogId = descriptor.catalogId;
  if (catalogId == null) return const [];
  return switch (await catalog.modelsFor(catalogId)) {
    CatalogListed(:final models) => models,
    CatalogUnavailable() => const [],
  };
}

/// The live entries, with the gaps each endpoint left filled from the
/// catalog's entry of the same id.
List<ProviderModel> enrichModels(
  List<ProviderModel> live,
  List<ProviderModel> known,
) {
  final byId = {for (final model in known) model.id: model};
  return [for (final model in live) _enrich(model, byId[model.id])];
}

ProviderModel _enrich(ProviderModel live, ProviderModel? known) {
  if (known == null) return live;
  return ProviderModel(
    id: live.id,
    name: live.name == live.id ? known.name : live.name,
    contextLength: live.contextLength ?? known.contextLength,
    supportsTools: live.supportsTools,
    reasoning: live.reasoning ?? known.reasoning,
    promptPricePerToken: live.promptPricePerToken ?? known.promptPricePerToken,
    completionPricePerToken:
        live.completionPricePerToken ?? known.completionPricePerToken,
  );
}
