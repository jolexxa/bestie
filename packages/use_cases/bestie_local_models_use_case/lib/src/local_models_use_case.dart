import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_local_models_use_case/src/config/local_models_config_keys.dart';
import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/panes/download_pane.dart';
import 'package:bestie_local_models_use_case/src/panes/installed_pane.dart';
import 'package:bestie_local_models_use_case/src/wording/command_statuses.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:clock/clock.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:provider_repository/provider_repository.dart';

/// Local models in the palette: the Installed and Download panes and the
/// model folders.
@useCase
class LocalModelsUseCase implements CommandContribution {
  LocalModelsUseCase({
    required LocalModelsRepository library,
    required BuiltInServerRepository server,
    required ProviderRepository providers,
    required ConfigRepository config,
    required LocalModelsConfigKeys configKeys,
    required ConfigKey<String> modelKey,
    required String providerId,
    required AgentRepository agents,
    required OSPlatformRepository platform,
    Clock clock = const Clock(),
  }) : _operations = LocalModelsOperations(
         library: library,
         server: server,
         providers: providers,
         config: config,
         configKeys: configKeys,
         modelKey: modelKey,
         providerId: providerId,
         agents: agents,
         platform: platform,
         clock: clock,
       ) {
    _downloadPane = DownloadPane(operations: _operations);
    final download = Command(
      id: 'models.download',
      title: 'Download models',
      glyph: '↓',
      description: 'Search Hugging Face for GGUF models',
      group: group,
      availability: alwaysAvailable(),
      body: CommandPane(_downloadPane),
    );
    final addFolder = Command(
      id: 'models.add_folder',
      title: 'Add model folder',
      glyph: '⊕',
      description: 'Scan a folder of .gguf files, including subfolders',
      group: group,
      availability: alwaysAvailable(),
      body: CommandFlow(next: _addFolderFlow, invoke: _addFolderInvoke),
    );
    commands = List.unmodifiable([
      Command(
        id: 'models.installed',
        title: 'Installed models',
        glyph: '▤',
        description: 'Downloads, your GGUF folders and the built-in server',
        tier: CommandTier.primary,
        group: group,
        availability: alwaysAvailable(),
        status: _operations.library.map(downloadsStatus),
        body: CommandPane(
          InstalledPane(
            operations: _operations,
            downloadCommand: download,
            addFolderCommand: addFolder,
          ),
        ),
      ),
      download,
      addFolder,
      Command(
        id: 'models.remove_folder',
        title: 'Remove model folder',
        glyph: '⊖',
        description: 'Stop listing the models in one of your folders',
        group: group,
        availability: gatedAvailability(
          () => _operations.folders,
          _operations.folderChanges,
          (folders) => folders.isEmpty
              ? const Unavailable(_noFolders)
              : const Available(),
        ),
        body: CommandFlow(
          next: _removeFolderFlow,
          invoke: _removeFolderInvoke,
        ),
      ),
    ]);
  }

  /// The palette group the commands list under.
  static const group = 'Local Models';

  static const _folderKey = ParamKey<String>('folder');
  static const _noFolders = 'no model folders added';

  final LocalModelsOperations _operations;
  late final DownloadPane _downloadPane;

  @override
  late final List<Command> commands;

  /// Picks the downloads up where they stood and scans the models folder
  /// and the user's folders.
  Future<void> start() => _operations.start();

  Future<void> dispose() async {
    await _downloadPane.dispose();
    await _operations.dispose();
  }

  Param? _addFolderFlow(Answers soFar) => soFar.maybe(_folderKey) == null
      ? TextParam(
          key: _folderKey,
          label: 'Folder',
          hint: '~/models, or any absolute path',
          validate: _folderProblem,
        )
      : null;

  String? _folderProblem(String typed) {
    final folder = _operations.folderFrom(typed);
    if (folder == null) return 'Use an absolute path, or one starting with ~';
    if (_operations.folders.contains(folder)) return 'Already a model folder';
    return null;
  }

  Future<CommandResult> _addFolderInvoke(Answers answers) async {
    final typed = answers.get(_folderKey);
    if (_folderProblem(typed) case final problem?) {
      return CommandRejected(problem);
    }
    _operations.setFolders([
      ..._operations.folders,
      _operations.folderFrom(typed)!,
    ]);
    return const CommandRan();
  }

  Param? _removeFolderFlow(Answers soFar) => soFar.maybe(_folderKey) == null
      ? ChoiceParam<String>.fixed(
          key: _folderKey,
          label: 'Folder',
          options: [
            for (final folder in _operations.folders)
              Option(
                value: folder,
                label: _operations.shorten(folder),
              ),
          ],
        )
      : null;

  Future<CommandResult> _removeFolderInvoke(Answers answers) async {
    final folder = answers.get(_folderKey);
    _operations.setFolders([
      for (final kept in _operations.folders)
        if (kept != folder) kept,
    ]);
    return const CommandRan();
  }
}
