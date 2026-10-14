import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hugging_face_client/src/client/expand_field.dart';
import 'package:hugging_face_client/src/client/hub_result.dart';
import 'package:hugging_face_client/src/client/paginated_response.dart';
import 'package:hugging_face_client/src/client/sort_direction.dart';
import 'package:hugging_face_client/src/models/git.dart';
import 'package:hugging_face_client/src/models/model.dart';
import 'package:hugging_face_client/src/models/repo.dart';
import 'package:intentions/intentions.dart';

/// Read-only, unauthenticated access to the public Hugging Face Hub API.
///
/// The injected [http.Client] stays owned by the caller, who closes it.
@dataSource
class HubClient {
  HubClient({required http.Client client, Uri? baseUrl})
    : _client = client,
      _baseUrl = baseUrl ?? Uri.parse('https://huggingface.co');

  final http.Client _client;
  final Uri _baseUrl;

  /// Searches models, one page at a time. Pass a previous page's
  /// [PaginatedResponse.nextUrl] as [cursor] to fetch the page after it; the
  /// other filters are then ignored because the cursor already carries them.
  Future<HfSearchResult> searchModels({
    String? search,
    String? author,
    String? filter,
    String? sort,
    SortDirection? direction,
    int? limit,
    String? pipelineTag,
    List<ModelExpandField> expand = const [],
    Uri? cursor,
  }) async {
    final url =
        cursor ??
        _url('/api/models', {
          'search': ?search,
          'author': ?author,
          'filter': ?filter,
          'sort': ?sort,
          'direction': ?direction?.value.toString(),
          'limit': ?limit?.toString(),
          'pipeline_tag': ?pipelineTag,
          ..._expand(expand),
        });
    return switch (await _get(url, _models)) {
      _HubReceived(:final value, :final headers) => HfSearchSucceeded(
        PaginatedResponse(
          items: value,
          nextUrl: parseLinkNext(headers['link']),
        ),
      ),
      _HubMissing(:final failure) || _HubFailed(:final failure) => failure,
    };
  }

  /// Fetches a model repository with blob metadata, so every sibling carries
  /// its size and, for LFS files, its sha256.
  Future<HfRepoResult> getModel(
    RepoId id, {
    String? revision,
    List<ModelExpandField> expand = const [],
  }) async {
    final revisionPath = revision == null
        ? ''
        : '/revision/${Uri.encodeComponent(revision)}';
    final url = _url('/api/models/${id.fullName}$revisionPath', {
      'blobs': 'true',
      ..._expand(expand),
    });
    return switch (await _get(url, _model)) {
      _HubReceived(:final value) => HfRepoResolved(value),
      _HubMissing() => HfRepoNotFound(id),
      _HubFailed(:final failure) => failure,
    };
  }

  /// Lists the entries under [path] in a repository at [revision].
  Future<HfTreeResult> listTree(
    RepoId id, {
    String revision = 'main',
    String path = '',
    bool recursive = false,
  }) async {
    final subPath = path.isEmpty ? '' : '/$path';
    final url = _url(
      '/api/models/${id.fullName}/tree/${Uri.encodeComponent(revision)}'
      '$subPath',
      {
        if (recursive) 'recursive': 'true',
      },
    );
    return switch (await _get(url, _treeEntries)) {
      _HubReceived(:final value) => HfTreeListed(value),
      _HubMissing() => HfRepoNotFound(id),
      _HubFailed(:final failure) => failure,
    };
  }

  /// The download URL for [filename] in a repository.
  Uri resolveFileUrl(RepoId id, String filename, {String revision = 'main'}) =>
      _baseUrl.replace(
        path:
            '/${id.fullName}/resolve/${Uri.encodeComponent(revision)}/'
            '$filename',
      );

  Uri _url(String path, Map<String, Object> query) => _baseUrl.replace(
    path: path,
    queryParameters: query.isEmpty ? null : query,
  );

  static Map<String, Object> _expand(List<ModelExpandField> fields) => {
    if (fields.isNotEmpty) 'expand': [for (final field in fields) field.value],
  };

  static List<HfModel> _models(Object? json) => [
    for (final item in _list(json)) HfModelMapper.fromMap(_object(item)),
  ];

  static HfModel _model(Object? json) => HfModelMapper.fromMap(_object(json));

  static List<GitTreeEntry> _treeEntries(Object? json) => [
    for (final item in _list(json)) GitTreeEntryMapper.fromMap(_object(item)),
  ];

  static List<Object?> _list(Object? json) => switch (json) {
    final List<Object?> list => list,
    _ => throw FormatException('Expected a JSON array', json),
  };

  static Map<String, dynamic> _object(Object? json) => switch (json) {
    final Map<String, dynamic> object => object,
    _ => throw FormatException('Expected a JSON object', json),
  };

  Future<_HubResponse<Value>> _get<Value>(
    Uri url,
    Value Function(Object? json) decode,
  ) async {
    try {
      final response = await _client.get(url);
      return switch (response.statusCode) {
        >= 200 && < 300 => _HubReceived(
          decode(jsonDecode(response.body)),
          response.headers,
        ),
        401 || 404 => _HubMissing(_failure(response)),
        _ => _HubFailed(_failure(response)),
      };
    } on Exception catch (error) {
      return _HubFailed(HfRequestFailed(message: '$error'));
    }
  }

  static HfRequestFailed _failure(http.Response response) => HfRequestFailed(
    message: switch (_tryJson(response.body)) {
      {'error': final String error} => error,
      _ => response.body,
    },
    statusCode: response.statusCode,
  );

  static Object? _tryJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

sealed class _HubResponse<Value> {
  const _HubResponse();
}

final class _HubReceived<Value> extends _HubResponse<Value> {
  const _HubReceived(this.value, this.headers);

  final Value value;
  final Map<String, String> headers;
}

final class _HubMissing<Value> extends _HubResponse<Value> {
  const _HubMissing(this.failure);

  final HfRequestFailed failure;
}

final class _HubFailed<Value> extends _HubResponse<Value> {
  const _HubFailed(this.failure);

  final HfRequestFailed failure;
}
