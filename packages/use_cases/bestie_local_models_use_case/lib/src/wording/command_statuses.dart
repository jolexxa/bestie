/// What the model commands' palette rows say the library and the local
/// server are doing.
library;

import 'package:bestie_local_models_use_case/src/models/local_server_status.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderCancelled, ProviderOccupied;

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
/// stopped on purpose. [nameOf] names a model by its local id.
CommandStatus? serverStatus(
  LocalServerStatus server, {
  required String Function(String localId) nameOf,
}) => switch (server) {
  ServerFailed(failure: ProviderCancelled()) => null,
  ServerFailed(failure: ProviderOccupied()) => const CommandStatus([
    PaneSpan('⚠ in use elsewhere', PaneTone.warning),
  ]),
  ServerFailed() => const CommandStatus([
    PaneSpan('✕ failed', PaneTone.danger),
  ]),
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
