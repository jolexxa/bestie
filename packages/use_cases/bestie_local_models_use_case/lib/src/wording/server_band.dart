import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_server_protocol/local_server_protocol.dart'
    show bestieProtocolVersion, bestieServerBusyMessage;

/// The line under the Installed pane's query that says what the built-in
/// server is doing, offering [retry] when it is off or failed. [nameOf]
/// names a model by its local id and [freeBytes] is the memory nothing is
/// using.
PaneStatus serverBand(
  BuiltInServerStatus server, {
  required String Function(String localId) nameOf,
  required int freeBytes,
  required PaneAction retry,
}) {
  final free = [
    PaneSpan('${wholeGigabytesLabel(freeBytes)} free', PaneTone.success),
  ];
  return switch (server) {
    ServerOffline(:final reason) => PaneStatus(
      glyph: '○',
      spans: [
        const PaneSpan('Built-in server is off', PaneTone.muted),
        if (reason != null) PaneSpan(' · $reason', PaneTone.muted),
      ],
      actions: [retry],
      trailing: free,
    ),
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
