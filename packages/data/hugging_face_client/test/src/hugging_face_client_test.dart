import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

const _modelInfoJson = '''
{
  "id": "bartowski/Llama-3.2-1B-Instruct-GGUF",
  "author": "bartowski",
  "sha": "abc123",
  "lastModified": "2024-10-01T12:00:00.000Z",
  "private": false,
  "gated": false,
  "disabled": false,
  "downloads": 42000,
  "likes": 100,
  "library_name": "gguf",
  "tags": ["text-generation", "gguf"],
  "pipeline_tag": "text-generation",
  "createdAt": "2024-09-01T00:00:00.000Z",
  "usedStorage": 1407777762,
  "gguf": {
    "total": 1235814432,
    "architecture": "llama",
    "context_length": 131072,
    "chat_template": "{{ bos_token }}",
    "bos_token": "<|begin_of_text|>"
  },
  "siblings": [
    {"rfilename": ".gitattributes", "size": 1570},
    {
      "rfilename": "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
      "blobId": "3897cf31",
      "size": 807694464,
      "lfs": {
        "sha256": "6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83",
        "size": 807694464,
        "pointerSize": 135
      }
    }
  ]
}
''';

const _searchResultsJson = '''
[
  {"id": "google/gemma-3-1b-it", "downloads": 500000, "likes": 200},
  {"id": "unsloth/gemma-3-1b-it-GGUF", "downloads": 10000, "likes": 50}
]
''';

const _treeJson = '''
[
  {"path": "config.json", "type": "file", "oid": "abc", "size": 1121},
  {"path": "tokenizer", "type": "directory", "oid": "def"}
]
''';

class _MockHttpClient extends Mock implements http.Client {}

/// A response recorded from huggingface.co.
String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

final RepoId _repo = RepoId.tryParse('bartowski/Llama-3.2-1B-Instruct-GGUF')!;

HubClient _hub(Future<http.Response> Function(http.Request request) handler) =>
    HubClient(client: MockClient(handler));

void main() {
  setUpAll(() => registerFallbackValue(Uri()));

  group('RepoId', () {
    test('parses namespace/name', () {
      final id = RepoId.tryParse('bartowski/Llama-3.2-1B')!;

      expect(id.namespace, 'bartowski');
      expect(id.name, 'Llama-3.2-1B');
      expect(id.fullName, 'bartowski/Llama-3.2-1B');
      expect(id.toString(), 'bartowski/Llama-3.2-1B');
    });

    test('accepts letters, digits, dots, dashes and underscores', () {
      for (final raw in ['a/b', 'Qwen/Qwen3-0.6B', 'org_1/my.model-v2_x']) {
        expect(RepoId.tryParse(raw)?.fullName, raw, reason: raw);
      }
    });

    test('rejects anything but two valid segments', () {
      for (final raw in [
        'no-slash',
        '/leading',
        'trailing/',
        'a/b/c',
        '',
        '../b',
        'a/..',
        'a/.',
        'a/b..c',
        'a/b--c',
        'a/-b',
        'a/b.',
        'a/b c',
        'a/b?x',
        'a/%2e%2e',
      ]) {
        expect(RepoId.tryParse(raw), isNull, reason: raw);
      }
    });

    test('compares by value', () {
      final first = RepoId.tryParse('a/b');
      final same = RepoId.tryParse('a/b');
      final other = RepoId.tryParse('a/c');

      expect(first, same);
      expect(first.hashCode, same.hashCode);
      expect(first, isNot(other));
    });
  });

  group('GatedMode', () {
    const mapper = GatedModeMapper();

    test('decodes booleans and strings', () {
      expect(mapper.decode(false), GatedMode.notGated);
      expect(mapper.decode(true), GatedMode.manual);
      expect(mapper.decode('auto'), GatedMode.auto);
      expect(mapper.decode('manual'), GatedMode.manual);
      expect(mapper.decode('something_else'), GatedMode.notGated);
    });

    test('encodes to the wire format', () {
      expect(mapper.encode(GatedMode.notGated), false);
      expect(mapper.encode(GatedMode.auto), 'auto');
      expect(mapper.encode(GatedMode.manual), 'manual');
    });
  });

  group('parseLinkNext', () {
    test('parses a next link', () {
      expect(
        parseLinkNext(
          '<https://huggingface.co/api/models?cursor=abc>; rel="next"',
        ),
        Uri.parse('https://huggingface.co/api/models?cursor=abc'),
      );
    });

    test('returns null without a next link', () {
      expect(parseLinkNext(null), isNull);
      expect(
        parseLinkNext('<https://huggingface.co/api/models>; rel="prev"'),
        isNull,
      );
    });
  });

  group('HfModel', () {
    test('decodes model info with LFS siblings', () {
      final model = HfModelMapper.fromJson(_modelInfoJson);

      expect(model.id, 'bartowski/Llama-3.2-1B-Instruct-GGUF');
      expect(model.author, 'bartowski');
      expect(model.sha, 'abc123');
      expect(model.isPrivate, isFalse);
      expect(model.gated, GatedMode.notGated);
      expect(model.isDisabled, isFalse);
      expect(model.downloads, 42000);
      expect(model.likes, 100);
      expect(model.library, 'gguf');
      expect(model.pipelineTag, 'text-generation');
      expect(model.tags, ['text-generation', 'gguf']);
      expect(model.usedStorage, 1407777762);
      final gguf = model.siblings!.last;
      expect(gguf.relativeFilename, 'Llama-3.2-1B-Instruct-Q4_K_M.gguf');
      expect(gguf.size, 807694464);
      expect(gguf.blobId, '3897cf31');
      expect(gguf.lfs!.sha256, startsWith('6f85a640'));
      expect(gguf.lfs!.size, 807694464);
      expect(gguf.lfs!.pointerSize, 135);
      expect(model.siblings!.first.lfs, isNull);
      expect(
        model.gguf,
        const HfGgufInfo(
          total: 1235814432,
          architecture: 'llama',
          contextLength: 131072,
          chatTemplate: '{{ bos_token }}',
        ),
      );
    });
  });

  group('GitTreeEntry', () {
    test('decodes files and directories', () {
      final entries = [
        for (final item in jsonDecode(_treeJson) as List<Object?>)
          GitTreeEntryMapper.fromMap(item! as Map<String, dynamic>),
      ];

      expect(entries.first.path, 'config.json');
      expect(entries.first.type, GitEntryType.file);
      expect(entries.first.size, 1121);
      expect(entries.last.type, GitEntryType.directory);
      expect(entries.last.size, isNull);
    });

    test('round-trips last commit info', () {
      final entry = GitTreeEntry(
        path: 'model.gguf',
        type: GitEntryType.file,
        oid: 'abc123',
        size: 4096,
        lastCommit: GitLastCommitInfo(
          id: 'sha456',
          title: 'initial commit',
          date: DateTime.utc(2025, 1, 15),
        ),
      );

      final decoded = GitTreeEntryMapper.fromMap(entry.toMap());

      expect(decoded.lastCommit!.id, 'sha456');
      expect(decoded.lastCommit!.title, 'initial commit');
      expect(decoded.lastCommit!.date, DateTime.utc(2025, 1, 15));
    });
  });

  group('HubClient.searchModels', () {
    test('sends the filters and returns a page', () async {
      late Uri requested;
      final hub = _hub((request) async {
        requested = request.url;
        return http.Response(_searchResultsJson, 200);
      });

      final result = await hub.searchModels(
        search: 'gemma',
        author: 'google',
        filter: 'gguf',
        sort: 'downloads',
        direction: SortDirection.descending,
        limit: 2,
        pipelineTag: 'text-generation',
        expand: [ModelExpandField.downloads, ModelExpandField.likes],
      );

      expect(requested.path, '/api/models');
      expect(requested.queryParameters, containsPair('search', 'gemma'));
      expect(requested.queryParameters, containsPair('author', 'google'));
      expect(requested.queryParameters, containsPair('filter', 'gguf'));
      expect(requested.queryParameters, containsPair('sort', 'downloads'));
      expect(requested.queryParameters, containsPair('direction', '-1'));
      expect(requested.queryParameters, containsPair('limit', '2'));
      expect(
        requested.queryParameters,
        containsPair('pipeline_tag', 'text-generation'),
      );
      expect(requested.queryParametersAll['expand'], ['downloads', 'likes']);
      final page = (result as HfSearchSucceeded).page;
      expect(page.items.map((model) => model.id), [
        'google/gemma-3-1b-it',
        'unsloth/gemma-3-1b-it-GGUF',
      ]);
      expect(page.hasMore, isFalse);
      expect(page.nextUrl, isNull);
    });

    test('reads GGUF facts for each result when asked to', () async {
      late Uri requested;
      final hub = _hub((request) async {
        requested = request.url;
        return http.Response(_fixture('search_expand_gguf.json'), 200);
      });

      final result = await hub.searchModels(
        search: 'Qwen3-1.7B-GGUF',
        expand: [ModelExpandField.gguf, ModelExpandField.downloads],
      );

      expect(requested.queryParametersAll['expand'], ['gguf', 'downloads']);
      final model = (result as HfSearchSucceeded).page.items.single;
      expect(model.id, 'unsloth/Qwen3-1.7B-GGUF');
      expect(model.downloads, 83085);
      expect(model.gguf!.architecture, 'qwen3');
      expect(model.gguf!.chatTemplate, contains('enable_thinking'));
    });

    test('omits absent filters', () async {
      late Uri requested;
      final hub = _hub((request) async {
        requested = request.url;
        return http.Response('[]', 200);
      });

      await hub.searchModels();

      expect(requested, Uri.parse('https://huggingface.co/api/models'));
    });

    test('follows the next-page cursor', () async {
      final requested = <Uri>[];
      final hub = _hub((request) async {
        requested.add(request.url);
        return http.Response(
          requested.length == 1 ? _searchResultsJson : '[]',
          200,
          headers: {
            if (requested.length == 1)
              'link':
                  '<https://huggingface.co/api/models?cursor=page2>; rel="next"',
          },
        );
      });

      final first = await hub.searchModels(search: 'gemma');
      final firstPage = (first as HfSearchSucceeded).page;
      final second = await hub.searchModels(cursor: firstPage.nextUrl);

      expect(firstPage.hasMore, isTrue);
      expect(requested.last.queryParameters, {'cursor': 'page2'});
      expect((second as HfSearchSucceeded).page.items, isEmpty);
    });

    test('reports an error status with the Hub error message', () async {
      final hub = _hub(
        (_) async => http.Response('{"error": "Rate limited"}', 429),
      );

      final result = await hub.searchModels(search: 'gemma');

      expect(
        result,
        isA<HfRequestFailed>()
            .having((it) => it.statusCode, 'statusCode', 429)
            .having((it) => it.message, 'message', 'Rate limited'),
      );
    });

    test('reports a not-found status as a failed request', () async {
      final hub = _hub((_) async => http.Response('gone', 404));

      final result = await hub.searchModels(search: 'gemma');

      expect(
        result,
        isA<HfRequestFailed>()
            .having((it) => it.statusCode, 'statusCode', 404)
            .having((it) => it.message, 'message', 'gone'),
      );
    });

    test('reports a network failure without a status', () async {
      final hub = _hub(
        (_) async => throw const SocketException('connection refused'),
      );

      final result = await hub.searchModels(search: 'gemma');

      expect(
        result,
        isA<HfRequestFailed>()
            .having((it) => it.statusCode, 'statusCode', isNull)
            .having((it) => it.message, 'message', contains('refused')),
      );
    });

    test('reports a body it cannot decode', () async {
      for (final body in ['{"not": "a list"}', '[1]', 'not json']) {
        final hub = _hub((_) async => http.Response(body, 200));

        expect(await hub.searchModels(), isA<HfRequestFailed>(), reason: body);
      }
    });
  });

  group('HubClient.getModel', () {
    test('asks for blob metadata and resolves the repo', () async {
      late Uri requested;
      final hub = _hub((request) async {
        requested = request.url;
        return http.Response(_modelInfoJson, 200);
      });

      final result = await hub.getModel(_repo);

      expect(
        requested.path,
        '/api/models/bartowski/Llama-3.2-1B-Instruct-GGUF',
      );
      expect(requested.queryParameters, {'blobs': 'true'});
      final model = (result as HfRepoResolved).model;
      expect(model.siblings!.last.lfs!.sha256, startsWith('6f85a640'));
    });

    test('puts the revision and expand fields in the request', () async {
      late Uri requested;
      final hub = _hub((request) async {
        requested = request.url;
        return http.Response(_modelInfoJson, 200);
      });

      await hub.getModel(
        _repo,
        revision: 'dev',
        expand: [ModelExpandField.siblings, ModelExpandField.sha],
      );

      expect(requested.path, endsWith('/revision/dev'));
      expect(requested.queryParametersAll['expand'], ['siblings', 'sha']);
      expect(requested.queryParameters['blobs'], 'true');
    });

    test('reads GGUF facts and the canonical id without asking', () async {
      final hub = _hub(
        (_) async => http.Response(_fixture('model_blobs.json'), 200),
      );

      final result = await hub.getModel(
        RepoId.tryParse('unsloth/qwen3-1.7b-gguf')!,
      );

      final model = (result as HfRepoResolved).model;
      expect(model.id, 'unsloth/Qwen3-1.7B-GGUF');
      final gguf = model.gguf!;
      expect(gguf.architecture, 'qwen3');
      expect(gguf.contextLength, 40960);
      expect(gguf.total, 1720574976);
      expect(gguf.chatTemplate, contains('<|im_start|>'));
      expect(
        model.siblings!.where(
          (sibling) => sibling.relativeFilename.endsWith('.gguf'),
        ),
        everyElement(
          isA<SiblingInfo>().having(
            (sibling) => sibling.lfs?.sha256,
            'sha256',
            isNotNull,
          ),
        ),
      );
    });

    test('reports a missing repo for 404 and 401', () async {
      for (final status in [401, 404]) {
        final hub = _hub(
          (_) async =>
              http.Response('{"error": "Repository not found"}', status),
        );

        final result = await hub.getModel(_repo);

        expect(
          result,
          isA<HfRepoNotFound>().having((it) => it.repo, 'repo', _repo),
        );
      }
    });

    test('reports a server error with its raw body', () async {
      final hub = _hub((_) async => http.Response('Bad Gateway', 502));

      final result = await hub.getModel(_repo);

      expect(
        result,
        isA<HfRequestFailed>()
            .having((it) => it.statusCode, 'statusCode', 502)
            .having((it) => it.message, 'message', 'Bad Gateway'),
      );
    });
  });

  group('HubClient.listTree', () {
    test('lists a directory', () async {
      late Uri requested;
      final hub = _hub((request) async {
        requested = request.url;
        return http.Response(_treeJson, 200);
      });

      final result = await hub.listTree(_repo);

      expect(
        requested.toString(),
        'https://huggingface.co/api/models/bartowski/'
        'Llama-3.2-1B-Instruct-GGUF/tree/main',
      );
      expect((result as HfTreeListed).entries, hasLength(2));
    });

    test('lists a sub-path recursively at a revision', () async {
      late Uri requested;
      final hub = _hub((request) async {
        requested = request.url;
        return http.Response('[]', 200);
      });

      await hub.listTree(
        _repo,
        revision: 'dev',
        path: 'quants/q4',
        recursive: true,
      );

      expect(requested.path, endsWith('/tree/dev/quants/q4'));
      expect(requested.queryParameters, {'recursive': 'true'});
    });

    test('reports a missing repo', () async {
      final hub = _hub((_) async => http.Response('', 404));

      expect(await hub.listTree(_repo), isA<HfRepoNotFound>());
    });

    test('reports a failed request', () async {
      final hub = _hub((_) async => http.Response('', 500));

      expect(await hub.listTree(_repo), isA<HfRequestFailed>());
    });
  });

  group('HubClient.resolveFileUrl', () {
    final hub = HubClient(
      client: MockClient((_) async => http.Response('', 200)),
    );

    test('builds the resolve URL on main', () {
      expect(
        hub.resolveFileUrl(_repo, 'model.gguf').toString(),
        'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/'
        'resolve/main/model.gguf',
      );
    });

    test('builds the resolve URL at a revision on a custom host', () {
      final mirror = HubClient(
        client: MockClient((_) async => http.Response('', 200)),
        baseUrl: Uri.parse('https://hf-mirror.example'),
      );

      expect(
        mirror
            .resolveFileUrl(_repo, 'sub/model.gguf', revision: 'abc')
            .toString(),
        'https://hf-mirror.example/bartowski/Llama-3.2-1B-Instruct-GGUF/'
        'resolve/abc/sub/model.gguf',
      );
    });
  });

  test('leaves the injected http client open', () async {
    final client = _MockHttpClient();
    when(() => client.get(any())).thenAnswer(
      (_) async => http.Response('[]', 200),
    );

    await HubClient(client: client).searchModels();

    verifyNever(client.close);
  });

  test('percent-encodes a revision that holds a slash', () async {
    late Uri requested;
    final hub = _hub((request) async {
      requested = request.url;
      return http.Response('[]', 200);
    });

    await hub.getModel(_repo, revision: 'refs/pr/1');
    final model = requested.toString();
    await hub.listTree(_repo, revision: 'refs/pr/1');
    final tree = requested.toString();

    expect(model, contains('/revision/refs%2Fpr%2F1?'));
    expect(tree, endsWith('/tree/refs%2Fpr%2F1'));
    expect(
      hub.resolveFileUrl(_repo, 'model.gguf', revision: 'refs/pr/1').toString(),
      endsWith('/resolve/refs%2Fpr%2F1/model.gguf'),
    );
  });
}
