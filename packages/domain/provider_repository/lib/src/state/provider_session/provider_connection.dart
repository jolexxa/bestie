import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/src/model_enrichment.dart';
import 'package:provider_repository/src/models/provider_account.dart';

/// A built provider for one usable account. It lists its models as soon as
/// it is built and keeps that listing for as long as the account stands.
@model
final class ProviderConnection {
  ProviderConnection({
    required this.account,
    required this.provider,
    required ModelCatalog catalog,
  }) : _catalog = catalog {
    _models = _list();
  }

  final ProviderAccount account;

  final Provider provider;

  final ModelCatalog _catalog;

  Future<ProviderModelsResult>? _models;

  /// The live listing with the catalog's facts filled in. A failed fetch is
  /// forgotten so the next caller tries again.
  Future<ProviderModelsResult> get models => _models ??= _list();

  Future<ProviderModelsResult> _list() async {
    final result = await provider.models();
    switch (result) {
      case ProviderModelsFailed():
        _models = null;
        return result;
      case ProviderModelsListed(:final models):
        final known = await knownModels(_catalog, account.descriptor);
        return ProviderModelsListed(enrichModels(models, known));
    }
  }
}
