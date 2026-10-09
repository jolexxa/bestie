import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/repositories.dart';

void main() {
  late Repositories repositories;

  LocalModelsOperations operationsWith({Clock clock = const Clock()}) =>
      LocalModelsOperations(
        library: repositories.library,
        server: repositories.server,
        providers: repositories.providers,
        config: repositories.config,
        configKeys: repositories.configKeys,
        modelKey: modelKey,
        providerId: localProviderId,
        agents: repositories.agents,
        platform: repositories.platform,
        clock: clock,
        startTimer: Timer.new,
      );

  setUp(() => repositories = Repositories());

  group('library', () {
    test('opens with what the repository has now', () async {
      final operations = operationsWith();
      expect(operations.currentLibrary, same(readyLibrary));
      expect(await operations.library.first, same(readyLibrary));
      await operations.dispose();
    });

    test('redraws at most four times a second, landing the latest', () {
      fakeAsync((async) {
        final operations = operationsWith(
          clock: async.getClock(DateTime(2026)),
        );
        final seen = <ModelLibrary>[];
        operations.library.listen(seen.add);
        async.flushMicrotasks();
        final updates = [
          for (var tick = 0; tick < 40; tick++)
            ModelLibrary(
              status: const LibraryReady(),
              downloading: [
                modelDownload(
                  status: DownloadTransferringStatus(receivedBytes: tick),
                ),
              ],
            ),
        ];
        for (final update in updates) {
          repositories.libraryChanges.add(update);
          async.elapse(const Duration(milliseconds: 25));
        }
        async.elapse(LocalModelsOperations.libraryInterval);
        expect(seen.first, same(readyLibrary));
        expect(seen.length - 1, lessThanOrEqualTo(5));
        expect(seen.last, same(updates.last));
        expect(operations.currentLibrary, same(updates.last));
        unawaited(operations.dispose());
        async.flushMicrotasks();
      });
    });

    test('stops following the repository once disposed', () {
      fakeAsync((async) {
        final operations = operationsWith(
          clock: async.getClock(DateTime(2026)),
        );
        unawaited(operations.dispose());
        async.flushMicrotasks();
        repositories.libraryChanges.add(readyLibrary);
        async.flushTimers();
        expect(repositories.libraryChanges.hasListener, isFalse);
      });
    });
  });

  group('folders', () {
    test('lists the folders the user added, now and as they change', () async {
      repositories.setFolders(['/a']);
      final operations = operationsWith();
      expect(operations.folders, ['/a']);
      final changes = <List<String>>[];
      final subscription = operations.folderChanges.listen(changes.add);
      await pumpEventQueue();
      repositories
        ..setFolders(['/a'])
        ..setFolders(['/a', '/b']);
      await pumpEventQueue();
      expect(changes, [
        ['/a'],
        ['/a', '/b'],
      ]);
      await subscription.cancel();
      await operations.dispose();
    });

    test(
      'rescans when the folders change, but not for the same list',
      () async {
        repositories.setFolders(['/a']);
        final operations = operationsWith();
        await pumpEventQueue();
        verifyNever(() => repositories.library.setFolders(any()));
        repositories.setFolders(['/a']);
        await pumpEventQueue();
        verifyNever(() => repositories.library.setFolders(any()));
        operations.setFolders(['/a', '/b']);
        await pumpEventQueue();
        verify(() => repositories.library.setFolders(['/a', '/b'])).called(1);
        expect(repositories.config[repositories.configKeys.paths.id], [
          '/a',
          '/b',
        ]);
        await operations.dispose();
      },
    );

    test('folderFrom expands ~ and normalizes absolute paths', () async {
      final operations = operationsWith();
      expect(operations.folderFrom('~'), homeDir);
      expect(operations.folderFrom('  ~/models/ '), '$homeDir/models');
      expect(operations.folderFrom('/opt/models/../gguf'), '/opt/gguf');
      expect(operations.folderFrom('models'), isNull);
      expect(operations.folderFrom('~joanna/models'), isNull);
      await operations.dispose();
    });
  });

  group('selected model', () {
    test('is the local model the app runs on', () async {
      repositories.select('local:qwen3-8b');
      final operations = operationsWith();
      expect(operations.selectedId, 'qwen3-8b');
      await operations.dispose();
    });

    test('is null for a hosted model or none', () async {
      final operations = operationsWith();
      expect(operations.selectedId, isNull);
      repositories.select('openrouter:qwen/qwen3-8b');
      expect(operations.selectedId, isNull);
      await operations.dispose();
    });
  });

  group('model in use', () {
    const failure = ProviderFailure(
      kind: InferenceFailureKind.server,
      message: 'out of memory',
    );

    test('is the local model the app runs or gets ready', () async {
      final operations = operationsWith();
      expect(operations.inUseId, isNull);

      repositories.report(runningOn('qwen3-8b'));
      expect(operations.inUseId, 'qwen3-8b');

      repositories.report(connectingTo('gemma'));
      expect(operations.inUseId, 'gemma');
      await operations.dispose();
    });

    test('is none while the app runs a hosted model or fails', () async {
      final operations = operationsWith();

      repositories.report(runningOn('qwen', providerId: 'openrouter'));
      expect(operations.inUseId, isNull);

      repositories.report(connectingTo('qwen', providerId: 'openrouter'));
      expect(operations.inUseId, isNull);

      repositories.report(failedOn('qwen3-8b', failure));
      expect(operations.inUseId, isNull);
      await operations.dispose();
    });

    test('follows the app, skipping repeats', () async {
      final operations = operationsWith();
      final seen = <String?>[];
      final subscription = operations.inUseIds.listen(seen.add);
      await pumpEventQueue();

      repositories
        ..report(connectingTo('qwen3-8b'))
        ..report(runningOn('qwen3-8b'))
        ..report(failedOn('qwen3-8b', failure));
      await pumpEventQueue();

      expect(seen, [null, 'qwen3-8b', null]);
      await subscription.cancel();
      await operations.dispose();
    });
  });

  group('failures', () {
    const failure = ProviderFailure(
      kind: InferenceFailureKind.server,
      message: 'out of memory',
    );

    test('say why the app could not run its local model', () async {
      final operations = operationsWith();
      final seen = <ProviderFailure?>[];
      final subscription = operations.failures.listen(seen.add);
      await pumpEventQueue();

      repositories
        ..report(failedOn('qwen3-8b', failure))
        ..report(failedOn('qwen3-8b', failure))
        ..report(failedOn('qwen', failure, providerId: 'openrouter'))
        ..report(runningOn('qwen3-8b'));
      await pumpEventQueue();

      expect(seen, [null, failure, null]);
      await subscription.cancel();
      await operations.dispose();
    });
  });

  group('use', () {
    test('runs the app on the local model', () async {
      final operations = operationsWith();
      expect(operations.use('qwen3-8b'), isA<ModelPicked>());
      expect(repositories.config[modelKey.id], 'local:qwen3-8b');
      await operations.dispose();
    });

    test('starts the model again when the app is already set to it', () async {
      repositories.select('local:qwen3-8b');
      final operations = operationsWith();

      expect(operations.use('qwen3-8b'), isA<ModelPicked>());

      verify(() => repositories.providers.reconnect()).called(1);
      expect(repositories.config[modelKey.id], 'local:qwen3-8b');
      await operations.dispose();
    });

    test('refuses while a turn is running', () async {
      repositories.phase = ConversationPhase.turnInFlight;
      final operations = operationsWith();
      expect(operations.idle, isFalse);
      expect(
        operations.use('qwen3-8b'),
        isA<ModelPickRefused>().having(
          (refused) => refused.reason,
          'reason',
          'turn in progress',
        ),
      );
      expect(repositories.config[modelKey.id], isNull);
      await operations.dispose();
    });
  });

  test('reads memory and the home folder from the platform', () async {
    final operations = operationsWith();
    expect(operations.memoryBytes, 24 * gigabyte);
    expect(operations.freeMemoryBytes, 18 * gigabyte);
    expect(operations.homeDir, homeDir);
    await operations.dispose();
  });

  test('shows the server the repository reports', () async {
    final operations = operationsWith();
    final next = operations.server.first;
    repositories.serverChanges.add(const ServerStarting());
    expect(await next, isA<ServerStarting>());
    await operations.dispose();
  });

  test('stops the local model through the app', () async {
    final operations = operationsWith()..stop();

    verify(() => repositories.providers.stop()).called(1);
    await operations.dispose();
  });

  test('retries the server by reconnecting the chosen model', () async {
    final operations = operationsWith()..retryServer();

    verify(() => repositories.providers.reconnect()).called(1);
    verifyNever(() => repositories.library.rescan());
    await operations.dispose();
  });

  test(
    'retrying the server takes the downloads over from a window that ran them',
    () async {
      when(() => repositories.library.current).thenReturn(
        const ModelLibrary(
          status: LibraryReady(),
          downloadsStatus: DownloadsManagedElsewhere(),
        ),
      );
      when(() => repositories.library.rescan()).thenAnswer((_) async {});
      final operations = operationsWith()..retryServer();

      verify(() => repositories.providers.reconnect()).called(1);
      verify(() => repositories.library.rescan()).called(1);
      await operations.dispose();
    },
  );

  test('hands library operations to the repository', () async {
    final library = repositories.library;
    final quant = repoQuant();
    const searched = RepoSearchSucceeded([gemmaRepo]);
    const resolved = RepoNotFound(repo: 'a/b');
    when(() => library.searchRepos('gemma')).thenAnswer((_) async => searched);
    when(() => library.resolveRepo('a/b')).thenAnswer((_) async => resolved);
    when(
      () => library.download(quant),
    ).thenAnswer((_) async => const DownloadAccepted('d'));
    when(() => library.cancel('d')).thenReturn(const CancelRequested());
    when(() => library.resume('d')).thenReturn(const ResumeQueued());
    when(
      () => library.discardDownload('d'),
    ).thenAnswer((_) async => const NothingToDiscard());
    when(
      () => library.deleteModel('m'),
    ).thenAnswer((_) async => const NothingToDelete());
    final operations = operationsWith();

    await operations.start();
    verify(library.start).called(1);
    expect(await operations.search('gemma'), same(searched));
    expect(await operations.resolve('a/b'), same(resolved));
    expect(await operations.download(quant), isA<DownloadAccepted>());
    expect(operations.cancel('d'), isA<CancelRequested>());
    expect(operations.resume('d'), isA<ResumeQueued>());
    expect(await operations.discard('d'), isA<NothingToDiscard>());
    expect(await operations.delete('m'), isA<NothingToDelete>());
    await operations.dispose();
  });
}
