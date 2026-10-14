import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_built_in_server_use_case/src/built_in_server_config_keys.dart';
import 'package:bestie_built_in_server_use_case/src/wording/server_status.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_local/provider_local.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:rxdart/rxdart.dart';

/// Runs the built-in server alongside bestie: starts it at boot, keeps it
/// loading models the way the user configured, and stops or restarts it
/// from the palette.
@useCase
class BuiltInServerUseCase implements CommandContribution {
  BuiltInServerUseCase({
    required ConfigRepository config,
    required BuiltInServerConfigKeys configKeys,
    required BuiltInServerRepository server,
    required ProviderRepository providers,
    required AgentRepository agents,
    required String providerId,
  }) : _config = config,
       _configKeys = configKeys,
       _server = server,
       _providers = providers,
       _agents = agents,
       _providerId = providerId {
    commands = List.unmodifiable([
      Command(
        id: 'server.stop',
        title: 'Stop built-in server',
        glyph: '⏻',
        description: 'Unload the model, free its memory and stop the server',
        group: group,
        availability: gatedAvailabilityOn([
          _server.statusStream,
          _agents.primaryConversationStream,
        ], _stopGate),
        status: _server.statusStream
            .throttleTime(statusInterval, trailing: true)
            .map(serverStatus),
        body: CommandFlow(
          invoke: _stopInvoke,
          running: 'Stopping the built-in server…',
        ),
      ),
      Command(
        id: 'server.restart',
        title: 'Restart built-in server',
        glyph: '↻',
        description: 'Start the server afresh and load the model again',
        group: group,
        availability: gatedAvailabilityOn([
          _agents.primaryConversationStream,
        ], _idleGate),
        body: CommandFlow(
          invoke: _restartInvoke,
          running: 'Restarting the built-in server…',
        ),
      ),
    ]);
    _server.configure(options);
    unawaited(_server.start());
    _configSub = _config.changes.listen(_onConfigChange);
  }

  /// The palette group the commands list under.
  static const group = 'Built-in server';

  /// The longest a palette row waits to show the server change; a load
  /// reports progress far more often than a terminal needs to redraw.
  static const statusInterval = Duration(milliseconds: 250);

  static const _notRunning = 'built-in server is not running';
  static const _turnRunning = 'turn in progress';

  @override
  late final List<Command> commands;

  final ConfigRepository _config;
  final BuiltInServerConfigKeys _configKeys;
  final BuiltInServerRepository _server;
  final ProviderRepository _providers;
  final AgentRepository _agents;
  final String _providerId;
  late final StreamSubscription<ConfigChange> _configSub;

  late final Set<String> _optionsKeyIds = {
    for (final key in _configKeys.optionsKeys) key.id,
  };

  /// How the server loads models, as configured right now.
  ModelLoadOptions get options {
    final contextCap = _config.resolve(_configKeys.contextCap.global);
    return ModelLoadOptions(contextCap: contextCap > 0 ? contextCap : null);
  }

  Future<void> dispose() => _configSub.cancel();

  void _onConfigChange(ConfigChange change) {
    if (!change.keyIds.any(_optionsKeyIds.contains)) return;
    _server.configure(options);
  }

  /// Whether the app is set to run a model on this server, so that stopping
  /// it stops the app's model too.
  bool get _runsHere => _providers.settings?.model?.providerId == _providerId;

  /// Stopping or restarting the server tears the app's model down, so both
  /// wait for the primary to finish its turn.
  Availability _idleGate() =>
      _agents.primary.conversationPhase == ConversationPhase.idle
      ? const Available()
      : const Unavailable(_turnRunning);

  Availability _stopGate() => _server.status is ServerRunning
      ? _idleGate()
      : const Unavailable(_notRunning);

  Future<CommandResult> _stopInvoke(Answers answers) async {
    if (_stopGate() case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    if (_runsHere) _providers.stop();
    await _server.stop();
    return const CommandRan();
  }

  Future<CommandResult> _restartInvoke(Answers answers) async {
    if (_idleGate() case Unavailable(:final reason)) {
      return CommandRejected(reason);
    }
    final runsHere = _runsHere;
    if (runsHere) _providers.stop();
    await _server.restart();
    if (runsHere) _providers.reconnect();
    return const CommandRan();
  }
}
