import 'dart:async';

import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Owns the visibility of bestie's modal overlays.
@useCase
class AppShellUseCase implements CommandContribution {
  AppShellUseCase() {
    commands = List.unmodifiable([
      Command(
        id: 'nav.openConfig',
        title: 'Open configuration',
        glyph: '⚙',
        shortcut: 'Ctrl+O',
        description: 'Edit providers, API keys, and the theme',
        tier: CommandTier.primary,
        group: 'App',
        availability: alwaysAvailable(),
        invoke: _openConfigInvoke,
      ),
    ]);
  }

  @override
  late final List<Command> commands;

  final _configController = StreamController<bool>.broadcast();
  final _paletteController = StreamController<bool>.broadcast();

  bool _configOpen = false;
  bool _paletteOpen = false;

  /// Whether the config overlay is open right now.
  bool get configOpen => _configOpen;

  /// Whether the command palette overlay is open right now.
  bool get paletteOpen => _paletteOpen;

  /// Emits [configOpen] on every change.
  Stream<bool> get configOpenChanges => _configController.stream;

  /// Emits [paletteOpen] on every change.
  Stream<bool> get paletteOpenChanges => _paletteController.stream;

  void toggleConfig() => _configOpen ? closeConfig() : openConfig();

  void openConfig() {
    _setPalette(false);
    _setConfig(true);
  }

  void closeConfig() => _setConfig(false);

  void togglePalette() => _paletteOpen ? closePalette() : openPalette();

  void openPalette() {
    _setConfig(false);
    _setPalette(true);
  }

  void closePalette() => _setPalette(false);

  void _setConfig(bool open) {
    if (_configOpen == open) return;
    _configOpen = open;
    _configController.add(open);
  }

  void _setPalette(bool open) {
    if (_paletteOpen == open) return;
    _paletteOpen = open;
    _paletteController.add(open);
  }

  Future<CommandResult> _openConfigInvoke(Answers answers) async {
    openConfig();
    return const CommandRan();
  }

  Future<void> dispose() async {
    await _configController.close();
    await _paletteController.close();
  }
}
