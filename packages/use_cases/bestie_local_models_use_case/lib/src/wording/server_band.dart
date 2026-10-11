import 'package:bestie_local_models_use_case/src/models/local_server_status.dart';
import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderCancelled, ProviderFailure, ProviderOccupied;

/// The line under the Installed pane's query that says what the local
/// server is doing, offering [retry] when it failed. [nameOf] names a model
/// by its local id and [freeBytes] is the memory nothing is using.
PaneStatus serverBand(
  LocalServerStatus server, {
  required String Function(String localId) nameOf,
  required int freeBytes,
  required PaneAction retry,
}) {
  final free = [
    PaneSpan('${wholeGigabytesLabel(freeBytes)} free', PaneTone.success),
  ];
  return switch (server) {
    ServerFailed(:final failure) => _failed(failure, retry: retry, free: free),
    ServerIdle() => PaneStatus(
      glyph: '○',
      spans: const [
        PaneSpan('Local server starts when you pick a model', PaneTone.muted),
      ],
      trailing: free,
    ),
    ServerStarting() => PaneStatus(
      spans: const [PaneSpan('Starting the local server')],
      progress: const PaneIndeterminate(),
      trailing: free,
    ),
    ServerLoading(:final localId, progress: null) => PaneStatus(
      glyph: '∷',
      glyphTone: PaneTone.secondary,
      spans: [
        const PaneSpan('Measuring how much context fits for '),
        PaneSpan(nameOf(localId), PaneTone.emphasis),
        const PaneSpan('…'),
      ],
      trailing: free,
    ),
    ServerLoading(:final localId, :final progress?) => PaneStatus(
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
  };
}

/// Why the app could not run on its local model, stopping on purpose
/// included.
PaneStatus _failed(
  ProviderFailure failure, {
  required PaneAction retry,
  required List<PaneSpan> free,
}) => switch (failure) {
  ProviderCancelled(:final message) => PaneStatus(
    glyph: '○',
    spans: [PaneSpan(message, PaneTone.muted)],
    actions: [retry],
    trailing: free,
  ),
  ProviderOccupied(:final message) => PaneStatus(
    glyph: '⚠',
    glyphTone: PaneTone.warning,
    spans: [PaneSpan(message, PaneTone.warning)],
    actions: [retry],
  ),
  ProviderFailure(:final message) => PaneStatus(
    glyph: '✕',
    glyphTone: PaneTone.danger,
    spans: [PaneSpan(message, PaneTone.danger)],
    actions: [retry],
  ),
};
