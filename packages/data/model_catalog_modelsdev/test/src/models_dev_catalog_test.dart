import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:model_catalog_modelsdev/model_catalog_modelsdev.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

const Map<String, Object?> _document = {
  'fireworks-ai': {
    'id': 'fireworks-ai',
    'name': 'Fireworks AI',
    'models': {
      'accounts/fireworks/models/kimi': {
        'name': 'Kimi K3',
        'reasoning': true,
        'reasoning_options': [
          {'type': 'toggle'},
          {
            'type': 'effort',
            'values': ['low', 'medium', 'high'],
          },
          {'type': 'budget_tokens', 'min': 1024},
        ],
        'tool_call': true,
        'limit': {'context': 262144, 'output': 32768},
        'cost': {'input': 1.25, 'output': 10},
      },
      'accounts/fireworks/models/toggle': {
        'name': 'Toggle',
        'reasoning': true,
        'reasoning_options': [
          {'type': 'toggle'},
        ],
        'tool_call': false,
      },
      'accounts/fireworks/models/none': {
        'name': 'Optional',
        'reasoning': true,
        'reasoning_options': [
          {
            'type': 'effort',
            'values': ['none', 'low', 'high'],
          },
        ],
      },
      'accounts/fireworks/models/budget': {
        'name': 'Budget',
        'reasoning': true,
        'reasoning_options': [
          {'type': 'budget_tokens', 'min': 128, 'max': 32768},
        ],
      },
      'accounts/fireworks/models/always': {'name': 'Always', 'reasoning': true},
      'accounts/fireworks/models/plain': {'name': '', 'reasoning': false},
      'accounts/fireworks/models/broken': 'not a model',
    },
  },
  'broken': {'models': 'nope'},
};

void main() {
  late File cacheFile;
  late List<Uri> fetches;

  setUp(() {
    cacheFile = MemoryFileSystem().file(
      '/home/cow/.bestie/cache/models_dev.json',
    );
    fetches = [];
  });

  final now = DateTime.utc(2026, 9, 5, 12);

  ModelsDevCatalog catalogFor(
    http.Response Function(http.Request request) respond, {
    DateTime? at,
  }) => ModelsDevCatalog(
    client: MockClient((request) async {
      fetches.add(request.url);
      return respond(request);
    }),
    cacheFile: cacheFile,
    clock: Clock.fixed(at ?? now),
  );

  http.Response Function(http.Request) serve(
    Object? body, {
    int status = 200,
  }) =>
      (_) => http.Response(jsonEncode(body), status);

  void writeCache(Object? body, {required DateTime modifiedAt}) {
    cacheFile.parent.createSync(recursive: true);
    cacheFile
      ..writeAsStringSync(jsonEncode(body))
      ..setLastModifiedSync(modifiedAt);
  }

  const kimi = ProviderModel(
    id: 'accounts/fireworks/models/kimi',
    name: 'Kimi K3',
    contextLength: 262144,
    supportsTools: true,
    reasoning: ProviderReasoningEfforts(
      efforts: ['low', 'medium', 'high'],
      canDisable: true,
    ),
    promptPricePerToken: 0.00000125,
    completionPricePerToken: 0.00001,
  );

  test(
    'downloads the catalog, caches it, and maps every reasoning shape',
    () async {
      final catalog = catalogFor(serve(_document));

      final result = await catalog.modelsFor('fireworks-ai');

      expect(fetches, [Uri.parse('https://models.dev/api.json')]);
      expect(cacheFile.existsSync(), isTrue);
      expect((result as CatalogListed).models, const [
        kimi,
        ProviderModel(
          id: 'accounts/fireworks/models/toggle',
          name: 'Toggle',
          supportsTools: false,
          reasoning: ProviderReasoningToggle(),
        ),
        ProviderModel(
          id: 'accounts/fireworks/models/none',
          name: 'Optional',
          supportsTools: false,
          reasoning: ProviderReasoningEfforts(
            efforts: ['low', 'high'],
            canDisable: true,
          ),
        ),
        ProviderModel(
          id: 'accounts/fireworks/models/budget',
          name: 'Budget',
          supportsTools: false,
          reasoning: ProviderReasoningFixed(),
        ),
        ProviderModel(
          id: 'accounts/fireworks/models/always',
          name: 'Always',
          supportsTools: false,
          reasoning: ProviderReasoningFixed(),
        ),
        ProviderModel(
          id: 'accounts/fireworks/models/plain',
          name: 'accounts/fireworks/models/plain',
          supportsTools: false,
        ),
      ]);
    },
  );

  test('downloads once per instance', () async {
    final catalog = catalogFor(serve(_document));

    await catalog.modelsFor('fireworks-ai');
    final again = await catalog.modelsFor('fireworks-ai');

    expect(fetches, hasLength(1));
    expect((again as CatalogListed).models.first, kimi);
  });

  test('lists nothing for providers the catalog does not know', () async {
    final catalog = catalogFor(serve(_document));

    expect(
      ((await catalog.modelsFor('unknown')) as CatalogListed).models,
      isEmpty,
    );
    expect(
      ((await catalog.modelsFor('broken')) as CatalogListed).models,
      isEmpty,
    );
  });

  test('reads a fresh cache without touching the network', () async {
    writeCache(_document, modifiedAt: now.subtract(const Duration(hours: 1)));
    final catalog = catalogFor(serve(const {}, status: 500));

    final result = await catalog.modelsFor('fireworks-ai');

    expect(fetches, isEmpty);
    expect((result as CatalogListed).models.first, kimi);
  });

  test('refreshes a stale cache', () async {
    writeCache(const {}, modifiedAt: now.subtract(const Duration(days: 2)));
    final catalog = catalogFor(serve(_document));

    final result = await catalog.modelsFor('fireworks-ai');

    expect(fetches, hasLength(1));
    expect((result as CatalogListed).models.first, kimi);
    expect(jsonDecode(cacheFile.readAsStringSync()), _document);
  });

  test('falls back to a stale cache when the download fails', () async {
    writeCache(_document, modifiedAt: now.subtract(const Duration(days: 2)));
    final catalog = catalogFor(serve(const {}, status: 503));

    final result = await catalog.modelsFor('fireworks-ai');

    expect(fetches, hasLength(1));
    expect((result as CatalogListed).models.first, kimi);
  });

  test('replaces an unreadable cache', () async {
    cacheFile.parent.createSync(recursive: true);
    cacheFile
      ..writeAsStringSync('not json')
      ..setLastModifiedSync(now);
    final catalog = catalogFor(serve(_document));

    final result = await catalog.modelsFor('fireworks-ai');

    expect(fetches, hasLength(1));
    expect((result as CatalogListed).models.first, kimi);
  });

  test(
    'reports HTTP failures when nothing is cached and retries later',
    () async {
      var status = 503;
      final catalog = catalogFor(
        (_) => http.Response(
          status == 200 ? jsonEncode(_document) : '{}',
          status,
        ),
      );

      final server = await catalog.modelsFor('fireworks-ai');
      expect(
        (server as CatalogUnavailable).failure,
        const ProviderFailure(
          kind: InferenceFailureKind.server,
          message: 'HTTP 503 fetching https://models.dev/api.json.',
        ),
      );

      status = 404;
      final client = await catalog.modelsFor('fireworks-ai');
      expect(
        (client as CatalogUnavailable).failure.kind,
        InferenceFailureKind.badRequest,
      );

      status = 200;
      final listed = await catalog.modelsFor('fireworks-ai');
      expect((listed as CatalogListed).models.first, kimi);
      expect(fetches, hasLength(3));
    },
  );

  test('reports transport failures as network failures', () async {
    final catalog = catalogFor((_) => throw http.ClientException('offline'));

    final result = await catalog.modelsFor('fireworks-ai');

    expect(
      (result as CatalogUnavailable).failure,
      const ProviderFailure(
        kind: InferenceFailureKind.network,
        message: 'offline',
      ),
    );
    expect(cacheFile.existsSync(), isFalse);
  });

  test('reports an unreadable download without caching it', () async {
    final bodies = ['not json', '[]'];
    for (final body in bodies) {
      final catalog = catalogFor((_) => http.Response(body, 200));

      final result = await catalog.modelsFor('fireworks-ai');

      expect(
        (result as CatalogUnavailable).failure,
        const ProviderFailure(
          kind: InferenceFailureKind.malformedResponse,
          message: 'models.dev returned an unreadable catalog.',
        ),
        reason: body,
      );
      expect(cacheFile.existsSync(), isFalse);
    }
  });
}
