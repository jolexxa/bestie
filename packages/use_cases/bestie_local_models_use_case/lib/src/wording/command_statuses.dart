/// What the model commands' palette rows say the library is doing.
library;

import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';

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
