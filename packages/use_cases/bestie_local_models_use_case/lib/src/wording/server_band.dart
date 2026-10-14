import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:built_in_server_client/built_in_server_client.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_server_protocol/local_server_protocol.dart'
    show
        ServerStopReason,
        bestieProtocolVersion,
        bestieServerBusyMessage,
        bestieServerExitMessage;

/// The line under the Installed pane's query that says what the built-in
/// server is doing, offering [retry] when it is off or failed. [nameOf]
/// names a model by its local id, [freeBytes] is the memory nothing is
/// using, and [logFile] is where the server wrote what happened to it.
PaneStatus serverBand(
  BuiltInServerStatus server, {
  required String Function(String localId) nameOf,
  required int freeBytes,
  required String logFile,
  required PaneAction retry,
}) {
  final free = [
    PaneSpan('${wholeGigabytesLabel(freeBytes)} free', PaneTone.success),
  ];
  return switch (server) {
    ServerOffline(:final cause) => switch (_lost(cause, logFile: logFile)) {
      null => PaneStatus(
        glyph: '○',
        spans: const [PaneSpan('Built-in server is off', PaneTone.muted)],
        actions: [retry],
        trailing: free,
      ),
      final lost => _failed(lost, retry: retry, trailing: free),
    },
    ServerStarting() => PaneStatus(
      spans: const [PaneSpan('Starting the built-in server')],
      progress: const PaneIndeterminate(),
      trailing: free,
    ),
    ServerIdle() => PaneStatus(
      glyph: '○',
      spans: const [
        PaneSpan('Built-in server is running · pick a model', PaneTone.muted),
      ],
      trailing: free,
    ),
    ServerFitting(:final localId) => PaneStatus(
      glyph: '∷',
      glyphTone: PaneTone.secondary,
      spans: [
        const PaneSpan('Measuring how much context fits for '),
        PaneSpan(nameOf(localId), PaneTone.emphasis),
        const PaneSpan('…'),
      ],
      trailing: free,
    ),
    ServerLoading(:final localId, :final progress) => PaneStatus(
      glyph: '◑',
      glyphTone: PaneTone.loading,
      spans: [
        const PaneSpan('Loading '),
        PaneSpan(nameOf(localId), PaneTone.emphasis),
      ],
      progress: PaneFraction(progress),
      trailing: free,
    ),
    ServerServing(
      :final localId,
      :final contextSize,
      :final maxAgents,
      :final leased,
    ) =>
      PaneStatus(
        glyph: '●',
        glyphTone: PaneTone.success,
        spans: [
          PaneSpan(nameOf(localId), PaneTone.emphasis),
          const PaneSpan('  ready · ', PaneTone.muted),
          PaneSpan('ctx ${groupedLabel(contextSize)}', PaneTone.info),
          if (leased != null) ...[
            const PaneSpan(' · ', PaneTone.muted),
            PaneSpan('$leased of $maxAgents agent slots in use'),
          ],
        ],
        trailing: free,
      ),
    ServerModelFailed(:final localId, :final reason) => _failed(
      'Could not load ${nameOf(localId)}: $reason',
      retry: retry,
      trailing: free,
    ),
    ServerTaken(:final ownerPid) => _warned(
      bestieServerBusyMessage(ownerPid),
      retry: retry,
    ),
    ServerIncompatible(:final protocolVersion) => _warned(
      'The running built-in server speaks protocol $protocolVersion; this '
      'bestie speaks $bestieProtocolVersion. It exits once its owner closes '
      'and it sits idle.',
      retry: retry,
    ),
    ServerFailed(:final reason) => _failed(
      'Could not start the built-in server: $reason',
      retry: retry,
      trailing: const [],
    ),
  };
}

/// How the server was lost, pointing at [logFile] when it says more; null
/// when it is off by this bestie's doing.
String? _lost(
  DisconnectCause cause, {
  required String logFile,
}) => switch (cause) {
  NotYetAttached() || SessionReleased() => null,
  ServerStopping(reason: ServerStopReason.requested) =>
    'Built-in server was asked to stop',
  ServerStopping(reason: ServerStopReason.engineLost) =>
    'Built-in server lost its engine · see $logFile',
  ServerStopping(:final reason) => 'Built-in server stopped (${reason.name})',
  ServerExited(:final exit, :final pid) =>
    'Built-in server ${bestieServerExitMessage(exit)} (pid $pid) · '
        'see $logFile',
  ServerDisappeared(:final pid) =>
    'Built-in server went away without notice (pid $pid) · see $logFile',
  AttachFailed(:final reason) => 'Could not take the built-in server: $reason',
};

PaneStatus _failed(
  String message, {
  required PaneAction retry,
  required List<PaneSpan> trailing,
}) => PaneStatus(
  glyph: '✕',
  glyphTone: PaneTone.danger,
  spans: [PaneSpan(message, PaneTone.danger)],
  actions: [retry],
  trailing: trailing,
);

PaneStatus _warned(String message, {required PaneAction retry}) => PaneStatus(
  glyph: '⚠',
  glyphTone: PaneTone.warning,
  spans: [PaneSpan(message, PaneTone.warning)],
  actions: [retry],
);
