import 'package:bestie_local_models_use_case/src/wording/command_statuses.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  String? textOf(CommandStatus? status) =>
      status == null ? null : spansText(status.spans);

  PaneTone toneOf(CommandStatus? status) => status!.spans.single.tone;

  group('downloadsStatus', () {
    ModelDownload sized(ModelDownloadStatus status) =>
        modelDownload(id: '$status', totalBytes: 100, status: status);

    test('is null with nothing downloading or waiting', () {
      expect(downloadsStatus(readyLibrary), isNull);
    });

    test('counts the active downloads and their share received', () {
      final status = downloadsStatus(
        ModelLibrary(
          downloading: [
            sized(const DownloadTransferringStatus(receivedBytes: 50)),
            sized(const DownloadQueuedStatus(receivedBytes: 10)),
            sized(const DownloadVerifyingStatus(receivedBytes: 100)),
            sized(const DownloadInstalledStatus()),
          ],
          needsAttention: [
            sized(const DownloadPausedStatus(receivedBytes: 0)),
          ],
        ),
      );
      expect(textOf(status), '↓ 4 · 65%');
      expect(toneOf(status), PaneTone.info);
      expect(status!.progress, closeTo(.65, 1e-9));
    });

    test('reads as no progress while sizes are unknown', () {
      final status = downloadsStatus(
        ModelLibrary(
          downloading: [
            modelDownload(
              totalBytes: 0,
              status: const DownloadQueuedStatus(),
            ),
          ],
        ),
      );
      expect(textOf(status), '↓ 1 · 0%');
      expect(status!.progress, 0);
    });

    test('counts the downloads waiting on the user', () {
      final one = downloadsStatus(
        ModelLibrary(
          needsAttention: [
            sized(const DownloadUnlistedStatus(UnlistedFileMissing())),
          ],
        ),
      );
      expect(textOf(one), '⚠ 1 needs attention');
      expect(toneOf(one), PaneTone.warning);
      expect(one!.progress, isNull);

      final two = downloadsStatus(
        ModelLibrary(
          needsAttention: [
            sized(const DownloadPausedStatus(receivedBytes: 20)),
            sized(
              const DownloadFailedStatus(
                reason: DownloadFailedEarlier('reset'),
                receivedBytes: 30,
              ),
            ),
          ],
        ),
      );
      expect(textOf(two), '⚠ 2 need attention');
      expect(toneOf(two), PaneTone.warning);
    });
  });
}
