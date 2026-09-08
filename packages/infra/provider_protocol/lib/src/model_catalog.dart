import 'package:provider_protocol/src/models/provider_failure.dart';
import 'package:provider_protocol/src/models/provider_model.dart';

/// An external source of model facts, keyed by the catalog's own provider
/// ids, for providers whose APIs say little about their models.
// ignore: one_member_abstracts
abstract interface class ModelCatalog {
  Future<CatalogResult> modelsFor(String catalogId);
}

/// The outcome of asking the catalog about one provider.
sealed class CatalogResult {
  const CatalogResult();
}

final class CatalogListed extends CatalogResult {
  const CatalogListed(this.models);

  final List<ProviderModel> models;
}

final class CatalogUnavailable extends CatalogResult {
  const CatalogUnavailable(this.failure);

  final ProviderFailure failure;
}
