import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:intentions/intentions.dart';
import 'package:model_catalog_modelsdev/src/models_dev_document.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// Reads model facts from models.dev, keeping one copy on disk so a fresh
/// download happens at most once a day and an older copy still serves when
/// the network is down.
@dataSource
final class ModelsDevCatalog implements ModelCatalog {
  ModelsDevCatalog({
    required http.Client client,
    required File cacheFile,
    Uri? source,
    Duration maxAge = const Duration(hours: 24),
    Clock clock = const Clock(),
  }) : _client = client,
       _cacheFile = cacheFile,
       _source = source ?? Uri.parse('https://models.dev/api.json'),
       _maxAge = maxAge,
       _clock = clock;

  final http.Client _client;
  final File _cacheFile;
  final Uri _source;
  final Duration _maxAge;
  final Clock _clock;

  Future<ModelsDevDocument?>? _document;
  late ProviderFailure _lastFailure;

  @override
  Future<CatalogResult> modelsFor(String catalogId) async {
    final loading = _document ??= _load();
    final document = await loading;
    if (document == null) {
      _document = null;
      return CatalogUnavailable(_lastFailure);
    }
    return CatalogListed(document.modelsFor(catalogId));
  }

  Future<ModelsDevDocument?> _load() async {
    final cached = _readCache();
    if (cached != null && _isFresh()) return cached;
    final fetched = await _fetch();
    return fetched ?? cached;
  }

  bool _isFresh() =>
      _clock.now().difference(_cacheFile.lastModifiedSync()) < _maxAge;

  ModelsDevDocument? _readCache() {
    if (!_cacheFile.existsSync()) return null;
    return ModelsDevDocument.parse(_cacheFile.readAsStringSync());
  }

  Future<ModelsDevDocument?> _fetch() async {
    try {
      final response = await _client.get(_source);
      if (response.statusCode != 200) {
        _lastFailure = ProviderFailure(
          kind: response.statusCode >= 500
              ? InferenceFailureKind.server
              : InferenceFailureKind.badRequest,
          message: 'HTTP ${response.statusCode} fetching $_source.',
        );
        return null;
      }
      final document = ModelsDevDocument.parse(response.body);
      if (document == null) {
        _lastFailure = const ProviderFailure(
          kind: InferenceFailureKind.malformedResponse,
          message: 'models.dev returned an unreadable catalog.',
        );
        return null;
      }
      _writeCache(response.body);
      return document;
    } on http.ClientException catch (error) {
      _lastFailure = ProviderFailure(
        kind: InferenceFailureKind.network,
        message: error.message,
      );
      return null;
    }
  }

  void _writeCache(String body) {
    _cacheFile.parent.createSync(recursive: true);
    _cacheFile.writeAsStringSync(body);
  }
}
