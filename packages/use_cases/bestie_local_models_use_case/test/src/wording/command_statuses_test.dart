import 'package:bestie_local_models_use_case/src/wording/command_statuses.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;
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

  group('serverStatus', () {
    const loadFailed = ProviderFailure(
      kind: InferenceFailureKind.server,
      message: 'The local model server ran out of memory.',
    );
    const stopped = ProviderFailure(
      kind: InferenceFailureKind.cancelled,
      message: 'Stopped.',
    );

    CommandStatus? statusOf(
      LocalServerStatus server, {
      ProviderFailure? failure,
    }) => serverStatus(
      server,
      failure: failure,
      nameOf: (localId) => localId == 'qwen3-8b' ? 'Qwen 3 8B' : localId,
    );

    test('is null while idle or stopped on purpose', () {
      expect(statusOf(const ServerIdle()), isNull);
      expect(
        statusOf(const ServerFailed('The server exited'), failure: stopped),
        isNull,
      );
    });

    test('names the model it serves', () {
      final status = statusOf(serving());
      expect(textOf(status), '● Qwen 3 8B ready');
      expect(toneOf(status), PaneTone.success);
    });

    test('follows the model getting ready', () {
      final starting = statusOf(const ServerStarting());
      expect(textOf(starting), '◑ starting');
      expect(toneOf(starting), PaneTone.loading);

      final fitting = statusOf(const ServerLoading(localId: 'qwen3-8b'));
      expect(textOf(fitting), '◑ fitting Qwen 3 8B');
      expect(toneOf(fitting), PaneTone.loading);

      final loading = statusOf(
        const ServerLoading(localId: 'qwen3-8b', progress: .424),
      );
      expect(textOf(loading), '◑ loading Qwen 3 8B 42%');
      expect(toneOf(loading), PaneTone.loading);
      expect(loading!.progress, isNull);
    });

    test('warns while another window holds the server', () {
      for (final server in const [
        ServerOwnedElsewhere(ownerPid: 4121),
        ServerIncompatible(serverVersion: '0.1.0', protocolVersion: 2),
      ]) {
        final status = statusOf(server, failure: loadFailed);
        expect(textOf(status), '⚠ in use elsewhere');
        expect(toneOf(status), PaneTone.warning);
      }
    });

    test('says it failed when the app or the server did', () {
      for (final status in [
        statusOf(serving(), failure: loadFailed),
        statusOf(const ServerFailed('The server exited')),
        statusOf(
          const ServerLoadFailed(localId: 'qwen3-8b', reason: 'out of memory'),
        ),
      ]) {
        expect(textOf(status), '✕ failed');
        expect(toneOf(status), PaneTone.danger);
      }
    });
  });
}
