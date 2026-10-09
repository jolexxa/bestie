import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:local_inference_protocol/local_inference_protocol.dart'
    show bestieServerBusyMessage;
import 'package:local_server_repository/local_server_repository.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;

/// The line under the Installed pane's query that says what the local
/// server is doing. [failure] is why the app could not run on its local
/// model, when it is set to one; [retry] is offered with it. [nameOf] names
/// a model by its local id and [freeBytes] is the memory nothing is using.
PaneStatus serverBand(
  LocalServerStatus server, {
  required ProviderFailure? failure,
  required String Function(String localId) nameOf,
  required int freeBytes,
  required PaneAction retry,
}) {
  final free = [
    PaneSpan('${wholeGigabytesLabel(freeBytes)} free', PaneTone.success),
  ];
  final retries = [?failure == null ? null : retry];
  return switch (server) {
    ServerOwnedElsewhere(:final ownerPid) => PaneStatus(
      glyph: '⚠',
      glyphTone: PaneTone.warning,
      spans: [
        PaneSpan(
          bestieServerBusyMessage(ownerPid),
          PaneTone.warning,
        ),
      ],
      actions: retries,
    ),
    ServerIncompatible(:final serverVersion, :final protocolVersion) =>
      PaneStatus(
        glyph: '⚠',
        glyphTone: PaneTone.warning,
        spans: [
          PaneSpan(
            'The running local server ($serverVersion) speaks protocol '
            '$protocolVersion; it exits once its owner closes.',
            PaneTone.warning,
          ),
        ],
        actions: retries,
      ),
    _ when failure != null => _failed(failure, retry: retry, free: free),
    ServerFailed(:final reason) => PaneStatus(
      spans: [PaneSpan(reason, PaneTone.muted)],
      trailing: free,
    ),
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
    ServerServing(:final localId, :final contextSize, :final pool) =>
      PaneStatus(
        glyph: '●',
        glyphTone: PaneTone.success,
        spans: [
          PaneSpan(nameOf(localId), PaneTone.emphasis),
          const PaneSpan('  ready · ', PaneTone.muted),
          PaneSpan('ctx ${groupedLabel(contextSize)}', PaneTone.info),
          if (pool case LocalAgentPool(:final leased, :final maxAgents)) ...[
            const PaneSpan(' · ', PaneTone.muted),
            PaneSpan('$leased of $maxAgents agent slots in use'),
          ],
        ],
        trailing: free,
      ),
    ServerLoadFailed(:final localId, :final reason) => PaneStatus(
      glyph: '✕',
      glyphTone: PaneTone.danger,
      spans: [
        PaneSpan(
          "The local server couldn't load ${nameOf(localId)}: $reason",
          PaneTone.danger,
        ),
      ],
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
  ProviderFailure(kind: InferenceFailureKind.cancelled, :final message) =>
    PaneStatus(
      glyph: '○',
      spans: [PaneSpan(message, PaneTone.muted)],
      actions: [retry],
      trailing: free,
    ),
  ProviderFailure(:final message) => PaneStatus(
    glyph: '✕',
    glyphTone: PaneTone.danger,
    spans: [PaneSpan(message, PaneTone.danger)],
    actions: [retry],
  ),
};
