import 'package:built_in_server_client/built_in_server_client.dart'
    show NotYetAttached, SessionReleased;
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:command_protocol/command_protocol.dart';

/// What the server commands' palette rows say the server is doing; null
/// while it is off by this bestie's doing.
CommandStatus? serverStatus(BuiltInServerStatus server) => switch (server) {
  ServerOffline(cause: NotYetAttached() || SessionReleased()) => null,
  ServerOffline() => const CommandStatus([
    PaneSpan('✕ gone', PaneTone.danger),
  ]),
  ServerStarting() => const CommandStatus([
    PaneSpan('◑ starting', PaneTone.loading),
  ]),
  ServerIdle() => const CommandStatus([
    PaneSpan('● running', PaneTone.success),
  ]),
  ServerFitting(:final localId) => CommandStatus([
    PaneSpan('◑ fitting $localId', PaneTone.loading),
  ]),
  ServerLoading(:final localId, :final progress) => CommandStatus([
    PaneSpan(
      '◑ loading $localId ${(progress * 100).round()}%',
      PaneTone.loading,
    ),
  ]),
  ServerServing(:final localId) => CommandStatus([
    PaneSpan('● $localId ready', PaneTone.success),
  ]),
  ServerModelFailed(:final localId) => CommandStatus([
    PaneSpan('✕ $localId failed', PaneTone.danger),
  ]),
  ServerTaken() => const CommandStatus([
    PaneSpan('⚠ in use elsewhere', PaneTone.warning),
  ]),
  ServerIncompatible() => const CommandStatus([
    PaneSpan('⚠ incompatible', PaneTone.warning),
  ]),
  ServerFailed() => const CommandStatus([
    PaneSpan('✕ failed', PaneTone.danger),
  ]),
};
