import 'dart:async';

import 'package:bestie_local_models_use_case/bestie_local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/panes/download_pane.dart';
import 'package:bestie_local_models_use_case/src/panes/installed_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
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
        '▤ Installed models · Downloads, your GGUF folders and the built-in '
        'server';
    const addFolder =
        '⊕ Add model folder · Scan a folder of .gguf files, including '
        'subfolders';
    const removeFolder =
        '⊖ Remove model folder · Stop listing the models in one of your '
        'folders';
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
