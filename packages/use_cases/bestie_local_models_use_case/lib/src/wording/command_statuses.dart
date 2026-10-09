/// What the model commands' palette rows say the library and the local
/// server are doing.
library;

import 'package:command_protocol/command_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;

/// How far the active downloads have got together, else how many wait on
/// the user; null when neither.
CommandStatus? downloadsStatus(ModelLibrary library) => switch (library) {
  ModelLibrary(downloading: final active) when active.isNotEmpty =>
    _downloading(active),
  ModelLibrary(needsAttention: [_]) => const CommandStatus([
    PaneSpan('⚠ 1 needs attention', PaneTone.warning),
  ]),
  ModelLibrary(:final needsAttention) when needsAttention.isNotEmpty =>
    CommandStatus([
      PaneSpan('⚠ ${needsAttention.length} need attention', PaneTone.warning),
    ]),
  ModelLibrary() => null,
};

CommandStatus _downloading(List<ModelDownload> active) {
  final total = active.fold(0, (sum, download) => sum + download.totalBytes);
  final received = active.fold(0, (sum, download) => sum + _received(download));
  final share = total == 0 ? 0.0 : received / total;
  return CommandStatus([
    PaneSpan('↓ ${active.length} · ${(share * 100).round()}%', PaneTone.info),
  ], progress: share);
}

int _received(ModelDownload download) => switch (download.status) {
  DownloadQueuedStatus(:final receivedBytes) ||
  DownloadTransferringStatus(:final receivedBytes) ||
  DownloadVerifyingStatus(:final receivedBytes) ||
  DownloadPausedStatus(:final receivedBytes) ||
  DownloadFailedStatus(:final receivedBytes) => receivedBytes,
  DownloadInstalledStatus() || DownloadUnlistedStatus() => download.totalBytes,
};

/// What the local server is doing for the app, null when it is idle or was
/// stopped on purpose. [failure] is why the app could not run on its local
/// model; [nameOf] names a model by its local id.
CommandStatus? serverStatus(
  LocalServerStatus server, {
  required ProviderFailure? failure,
  required String Function(String localId) nameOf,
}) => switch (server) {
  ServerOwnedElsewhere() || ServerIncompatible() => const CommandStatus([
    PaneSpan('⚠ in use elsewhere', PaneTone.warning),
  ]),
  _ when failure?.kind == InferenceFailureKind.cancelled => null,
  _ when failure != null => _failed,
  ServerFailed() || ServerLoadFailed() => _failed,
  ServerIdle() => null,
  ServerStarting() => const CommandStatus([
    PaneSpan('◑ starting', PaneTone.loading),
  ]),
  ServerLoading(:final localId, progress: null) => CommandStatus([
    PaneSpan('◑ fitting ${nameOf(localId)}', PaneTone.loading),
  ]),
  ServerLoading(:final localId, :final progress?) => CommandStatus([
    PaneSpan(
      '◑ loading ${nameOf(localId)} ${(progress * 100).round()}%',
      PaneTone.loading,
    ),
  ]),
  ServerServing(:final localId) => CommandStatus([
    PaneSpan('● ${nameOf(localId)} ready', PaneTone.success),
  ]),
};

const _failed = CommandStatus([PaneSpan('✕ failed', PaneTone.danger)]);
