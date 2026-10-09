import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_local_models_use_case/bestie_local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/panes/download_pane.dart';
import 'package:bestie_local_models_use_case/src/panes/installed_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:fake_async/fake_async.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/repositories.dart';

void main() {
  late Repositories repositories;
  late LocalModelsUseCase useCase;

  setUp(() {
    repositories = Repositories();
    useCase = LocalModelsUseCase(
      library: repositories.library,
      server: repositories.server,
      providers: repositories.providers,
      config: repositories.config,
      configKeys: repositories.configKeys,
      modelKey: modelKey,
      providerId: localProviderId,
      agents: repositories.agents,
      platform: repositories.platform,
    );
  });

  tearDown(() => useCase.dispose());

  Command command(String id) =>
      useCase.commands.firstWhere((command) => command.id == id);

  CommandFlow flowOf(String id) => command(id).body as CommandFlow;

  Future<Availability> availabilityOf(String id) =>
      command(id).availability.first;

  test('contributes the Models group', () {
    const installed =
        '▤ Installed models · Downloads, your GGUF folders and the local '
        'server';
    const addFolder =
        '⊕ Add model folder · Scan a folder of .gguf files, including '
        'subfolders';
    const removeFolder =
        '⊖ Remove model folder · Stop listing the models in one of your '
        'folders';
    const stopServer =
        '⏻ Stop local server · Unload the model, free its memory and stop the '
        'server';
    expect(
      useCase.commands.map(
        (command) =>
            '${command.glyph} ${command.title} · ${command.description}',
      ),
      [
        installed,
        '↓ Download models · Search Hugging Face for GGUF models',
        addFolder,
        removeFolder,
        stopServer,
      ],
    );
    expect(
      useCase.commands.map((command) => command.group).toSet(),
      {LocalModelsUseCase.group},
    );
    expect(LocalModelsUseCase.group, 'Local Models');
    expect(command('models.installed').tier, CommandTier.primary);
  });

  test('Installed and Download open their panes', () async {
    final installed = (command('models.installed').body as CommandPane).pane;
    expect(installed, isA<InstalledPane>());
    expect(
      (installed as InstalledPane).downloadCommand,
      same(command('models.download')),
    );
    expect(installed.addFolderCommand, same(command('models.add_folder')));
    expect(
      (command('models.download').body as CommandPane).pane,
      isA<DownloadPane>(),
    );
    expect(await availabilityOf('models.installed'), isA<Available>());
    expect(await availabilityOf('models.download'), isA<Available>());
  });

  group('Add model folder', () {
    test('asks for a folder, then nothing more', () {
      final flow = flowOf('models.add_folder');
      final param = flow.next(const Answers.empty())! as TextParam;
      expect(param.label, 'Folder');
      expect(param.hint, '~/models, or any absolute path');
      expect(
        flow.next(const Answers.empty().put(param.key, '~/models')),
        isNull,
      );
    });

    test('accepts absolute paths and ~, and no folder twice', () {
      repositories.setFolders(['$homeDir/models']);
      final param =
          flowOf('models.add_folder').next(const Answers.empty())! as TextParam;
      expect(param.validate!('/opt/gguf'), isNull);
      expect(param.validate!('~/Downloads'), isNull);
      expect(
        param.validate!('models'),
        'Use an absolute path, or one starting with ~',
      );
      expect(param.validate!('~/models'), 'Already a model folder');
    });

    test('adds the folder to models.paths', () async {
      repositories.setFolders(['/opt/gguf']);
      final flow = flowOf('models.add_folder');
      final param = flow.next(const Answers.empty())! as TextParam;
      final result = await flow.invoke(
        const Answers.empty().put(param.key, '~/models/'),
      );
      expect(result, isA<CommandRan>());
      expect(repositories.config[repositories.configKeys.paths.id], [
        '/opt/gguf',
        '$homeDir/models',
      ]);
    });

    test('refuses a folder that slipped past the prompt', () async {
      final flow = flowOf('models.add_folder');
      final param = flow.next(const Answers.empty())! as TextParam;
      final result = await flow.invoke(
        const Answers.empty().put(param.key, 'relative'),
      );
      expect(
        (result as CommandRejected).reason,
        'Use an absolute path, or one starting with ~',
      );
      expect(repositories.config[repositories.configKeys.paths.id], isNull);
    });
  });

  group('Remove model folder', () {
    test('is unavailable until a folder is added', () async {
      final availability = <Availability>[];
      final subscription = command(
        'models.remove_folder',
      ).availability.listen(availability.add);
      await pumpEventQueue();
      repositories.setFolders(['/opt/gguf']);
      await pumpEventQueue();
      expect(
        (availability.first as Unavailable).reason,
        'no model folders added',
      );
      expect(availability.last, isA<Available>());
      await subscription.cancel();
    });

    test('offers each folder, written with ~', () async {
      repositories.setFolders(['$homeDir/models', '/opt/gguf']);
      final flow = flowOf('models.remove_folder');
      final param = flow.next(const Answers.empty())! as ChoiceParam<String>;
      final options = await param.options.first;
      expect(options.map((option) => '${option.value} ${option.label}'), [
        '$homeDir/models ~/models',
        '/opt/gguf /opt/gguf',
      ]);
      expect(
        flow.next(const Answers.empty().put(param.key, '/opt/gguf')),
        isNull,
      );
    });

    test('removes the chosen folder from models.paths', () async {
      repositories.setFolders(['$homeDir/models', '/opt/gguf']);
      final flow = flowOf('models.remove_folder');
      final param = flow.next(const Answers.empty())! as ChoiceParam<String>;
      final result = await flow.invoke(
        const Answers.empty().put(param.key, '$homeDir/models'),
      );
      expect(result, isA<CommandRan>());
      expect(repositories.config[repositories.configKeys.paths.id], [
        '/opt/gguf',
      ]);
    });
  });

  group('Stop local server', () {
    test('is unavailable while no local model runs', () async {
      repositories.report(runningOn('qwen', providerId: 'openrouter'));
      expect(
        (await availabilityOf('models.stop_server') as Unavailable).reason,
        'no local model running',
      );
    });

    test('is unavailable while a turn is running', () async {
      repositories
        ..report(runningOn('qwen3-8b'))
        ..phase = ConversationPhase.turnInFlight;
      expect(
        (await availabilityOf('models.stop_server') as Unavailable).reason,
        'turn in progress',
      );
    });

    test('follows the model the app runs', () async {
      final availability = <Availability>[];
      final subscription = command(
        'models.stop_server',
      ).availability.listen(availability.add);
      await pumpEventQueue();
      expect(availability.last, isA<Unavailable>());

      repositories.report(connectingTo('qwen3-8b'));
      await pumpEventQueue();
      expect(availability.last, isA<Available>());

      repositories.report(runningOn('qwen', providerId: 'openrouter'));
      await pumpEventQueue();
      expect(
        (availability.last as Unavailable).reason,
        'no local model running',
      );
      await subscription.cancel();
    });

    test('stops the local model the app runs', () async {
      repositories.report(runningOn('qwen3-8b'));
      final flow = flowOf('models.stop_server');
      expect(flow.running, 'Stopping the local model…');
      expect(flow.next(const Answers.empty()), isNull);
      expect(await flow.invoke(const Answers.empty()), isA<CommandRan>());
      verify(() => repositories.providers.stop()).called(1);
    });

    test('refuses when there is nothing to stop', () async {
      final result = await flowOf('models.stop_server').invoke(
        const Answers.empty(),
      );
      expect((result as CommandRejected).reason, 'no local model running');
      verifyNever(() => repositories.providers.stop());
    });
  });

  group('row statuses', () {
    String? textOf(CommandStatus? status) =>
        status?.spans.map((span) => span.text).join();

    test('Installed models follows the downloads', () async {
      final statuses = <CommandStatus?>[];
      final subscription = command(
        'models.installed',
      ).status.listen(statuses.add);
      await pumpEventQueue();
      expect(statuses, [null]);

      repositories.libraryChanges.add(
        ModelLibrary(downloading: [modelDownload()]),
      );
      await pumpEventQueue();
      expect(textOf(statuses.last), '↓ 1 · 50%');
      expect(statuses.last!.progress, .5);
      await subscription.cancel();
    });

    test('Stop local server follows the server at a drawable pace, even '
        'while it cannot run', () {
      fakeAsync((async) {
        final paced = LocalModelsUseCase(
          library: repositories.library,
          server: repositories.server,
          providers: repositories.providers,
          config: repositories.config,
          configKeys: repositories.configKeys,
          modelKey: modelKey,
          providerId: localProviderId,
          agents: repositories.agents,
          platform: repositories.platform,
          clock: async.getClock(DateTime(2026)),
        );
        final stop = paced.commands.firstWhere(
          (command) => command.id == 'models.stop_server',
        );
        final statuses = <String?>[];
        final availability = <Availability>[];
        stop.status.listen((status) => statuses.add(textOf(status)));
        stop.availability.listen(availability.add);
        repositories.libraryChanges.add(
          ModelLibrary(downloaded: [supportedModel()]),
        );
        async.flushMicrotasks();

        repositories.serverChanges.add(
          const ServerOwnedElsewhere(ownerPid: 4121),
        );
        async.flushMicrotasks();
        expect(statuses.last, '⚠ in use elsewhere');
        expect(availability.last, isA<Unavailable>());

        async.elapse(LocalModelsOperations.libraryInterval);
        for (final progress in [.1, .2, .3]) {
          repositories.serverChanges.add(
            ServerLoading(localId: 'qwen3-8b', progress: progress),
          );
        }
        async.flushMicrotasks();
        expect(statuses.last, '◑ loading Qwen 3 8B 10%');
        async.elapse(LocalModelsOperations.libraryInterval);
        expect(statuses.last, '◑ loading Qwen 3 8B 30%');
        expect(statuses, isNot(contains('◑ loading Qwen 3 8B 20%')));

        unawaited(paced.dispose());
        async.flushMicrotasks();
      });
    });
  });

  test('start picks the library up', () async {
    await useCase.start();
    verify(() => repositories.library.start()).called(1);
  });

  test('stops following the library once disposed', () async {
    await useCase.dispose();
    expect(repositories.libraryChanges.hasListener, isFalse);
  });
}
