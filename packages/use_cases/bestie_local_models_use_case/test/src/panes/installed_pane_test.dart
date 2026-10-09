import 'dart:async';

import 'package:bestie_local_models_use_case/src/panes/installed_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

Command _command(String id) => Command(
  id: id,
  title: id,
  description: id,
  group: 'Local Models',
  availability: alwaysAvailable(),
  body: CommandFlow(invoke: (_) async => const CommandRan()),
);

void main() {
  final download = _command('models.download');
  final addFolder = _command('models.add_folder');

  late MockLocalModelsOperations operations;

  setUp(() => operations = MockLocalModelsOperations());

  InstalledPane pane() => InstalledPane(
    operations: operations,
    downloadCommand: download,
    addFolderCommand: addFolder,
  );

  Future<PaneContent> contentOf(ModelLibrary library, {String? running}) {
    stubOperations(operations, currentLibrary: library, inUseId: running);
    return pane().content('').first;
  }

  Future<PaneRow> downloadRow(ModelDownloadStatus status) async {
    final content = await contentOf(
      ModelLibrary(
        status: const LibraryReady(),
        downloadsStatus: const DownloadsReady(),
        downloading: [modelDownload(status: status)],
      ),
    );
    return content.rows.single;
  }

  test('lists installed models behind a fuzzy filter', () {
    expect(pane().title, 'Installed');
    expect(pane().placeholder, 'Filter models…');
    expect(pane().filter, PaneFilter.fuzzy);
  });

  test('bands what the server does, naming models from the library', () async {
    stubOperations(
      operations,
      currentLibrary: ModelLibrary(
        status: const LibraryReady(),
        downloaded: [supportedModel()],
      ),
      server: Stream.value(
        serving(pool: const LocalAgentPool(leased: 2, maxAgents: 4)),
      ),
    );
    final band = await pane().status.first;
    expect(
      spansText(band!.spans),
      'Qwen 3 8B  ready · ctx 32,768 · 2 of 4 agent slots in use',
    );
    expect(spansText(band.trailing), '18 GB free');
  });

  test('retries the server from its band once it failed', () async {
    stubOperations(
      operations,
      failures: Stream.value(
        const ProviderFailure(
          kind: InferenceFailureKind.server,
          message: 'Could not start the local model server: no binary',
        ),
      ),
    );
    when(() => operations.retryServer()).thenReturn(null);

    final retry = (await pane().status.first)!.actionFor(const CharKey('r'))!;

    expect(retry.label, 'Retry');
    expect(await retry.invoke(), isA<PaneStay>());
    verify(() => operations.retryServer()).called(1);
  });

  test('bands a model the library no longer has by its id', () async {
    stubOperations(
      operations,
      server: Stream.value(const ServerLoading(localId: 'mystery')),
    );
    expect(
      spansText((await pane().status.first)!.spans),
      'Measuring how much context fits for mystery…',
    );
  });

  test('shows nothing until the first scan finishes', () async {
    final library = StreamController<ModelLibrary>();
    stubOperations(operations, library: library.stream);
    final contents = <PaneContent>[];
    final subscription = pane().content('').listen(contents.add);
    library.add(ModelLibrary.loading);
    await pumpEventQueue();
    expect(contents, isEmpty);
    library.add(readyLibrary);
    await pumpEventQueue();
    expect(contents, hasLength(1));
    await subscription.cancel();
  });

  group('with no models', () {
    test('invites a download or a folder', () async {
      final content = await contentOf(readyLibrary);
      final section = content.sections.single;
      const invitation =
          'Download one from Hugging Face, or point bestie at a folder of '
          'GGUFs you already have.';
      expect(section.notes.map(noteText), [
        '',
        'No local models yet.',
        invitation,
        '',
      ]);
      expect(section.rows.map((row) => '${row.glyph} ${row.label}'), [
        '↓ Download a model',
        '⊕ Add a model folder',
      ]);
      expect(section.rows.first.tint, PaneTint.primary);
      expect(
        spansText(section.rows.first.detail),
        'Search Hugging Face for GGUF models',
      );
      expect(
        spansText(section.rows.last.detail),
        'Bestie scans it and its subfolders for .gguf files',
      );
    });

    test('opens Download and Add model folder', () async {
      final rows = (await contentOf(readyLibrary)).rows;
      final opened = [
        for (final row in rows)
          (await actionOf(row, const PrimaryKey()).invoke() as PaneOpenCommand)
              .command,
      ];
      expect(opened, [same(download), same(addFolder)]);
    });

    test('says when scanning failed', () async {
      final content = await contentOf(
        const ModelLibrary(status: LibraryScanFailed('EACCES')),
      );
      expect(
        noteText(content.sections.single.notes[1]),
        "Couldn't scan for models: EACCES",
      );
    });
  });

  test('sections appear in order, counted, only when they have rows', () async {
    final content = await contentOf(
      ModelLibrary(
        status: const LibraryReady(),
        downloading: [modelDownload()],
        needsAttention: [
          modelDownload(
            id: 'paused',
            status: const DownloadPausedStatus(receivedBytes: 0),
          ),
        ],
        downloaded: [
          supportedModel(),
          supportedModel(id: 'gemma', displayName: 'Gemma 4 26B-A4B Instruct'),
        ],
        inFolders: [
          supportedModel(
            id: 'llama',
            displayName: 'Llama 3.2 3B Instruct',
            source: const ScannedSource(root: '$homeDir/models'),
            path: '$homeDir/models/Llama-3.2-3B.gguf',
          ),
          unsupportedModel(),
        ],
      ),
      running: 'qwen3-8b',
    );
    expect(
      content.sections.map((section) => '${section.title} ${section.count}'),
      [
        'Downloading 1',
        'Needs attention 1',
        'In use 1',
        'Downloaded 1',
        'In your folders 2',
      ],
    );
    expect(content.sections[3].rows.single.label, 'Gemma 4 26B-A4B Instruct');
  });

  test('a model from your folders in use moves to In use', () async {
    final content = await contentOf(
      ModelLibrary(
        status: const LibraryReady(),
        inFolders: [
          supportedModel(
            id: 'llama',
            source: const ScannedSource(root: '$homeDir/models'),
          ),
        ],
      ),
      running: 'llama',
    );
    expect(content.sections.map((section) => section.title), ['In use']);
  });

  group('downloads note', () {
    Future<String?> noteFor(DownloadsStatus status) async {
      final content = await contentOf(
        ModelLibrary(
          status: const LibraryReady(),
          downloaded: [supportedModel()],
          downloadsStatus: status,
        ),
      );
      final first = content.sections.first;
      return first.title == null ? noteText(first.notes.single) : null;
    }

    test('is absent while downloads run here', () async {
      expect(await noteFor(const DownloadsReady()), isNull);
      expect(await noteFor(const DownloadsStarting()), isNull);
    });

    test('warns when downloads are elsewhere, damaged or unsaved', () async {
      expect(
        await noteFor(const DownloadsManagedElsewhere()),
        '⚠ Another bestie window runs downloads; this one only shows them.',
      );
      expect(
        await noteFor(
          const DownloadsLedgerSetAside(reason: 'bad', movedTo: '/x.bak'),
        ),
        '⚠ The download list was damaged and was set aside at /x.bak.',
      );
      expect(
        await noteFor(const DownloadsLedgerUnreadable('EACCES')),
        "⚠ Downloads are paused: the download list can't be read (EACCES).",
      );
      expect(
        await noteFor(const DownloadsLedgerNotSaved('ENOSPC')),
        "⚠ Downloads run, but the download list couldn't be saved (ENOSPC).",
      );
    });
  });

  group('a download row', () {
    test('shows a transfer with its speed, time left and progress', () async {
      final row = await downloadRow(
        const DownloadTransferringStatus(
          receivedBytes: 5640000000,
          speedBytesPerSecond: 48300000,
        ),
      );
      expect(row.glyph, '◐');
      expect(row.label, 'gpt-oss-20b');
      expect(spansText(row.trailing), 'MXFP4 · 11.28 GB');
      expect(
        spansText(row.detail),
        '5.64 GB of 11.28 GB · 48.3 MB/s · about 1 min left',
      );
      expect((row.progress! as PaneFraction).value, 0.5);
      expect(actionLabels(row), ['Cancel']);
      expect(row.keywords, 'openai/gpt-oss-20b-GGUF MXFP4');
    });

    test('leaves out speed until it is known', () async {
      final row = await downloadRow(
        const DownloadTransferringStatus(receivedBytes: 0),
      );
      expect(spansText(row.detail), '0 MB of 11.28 GB');
      final stalled = await downloadRow(
        const DownloadTransferringStatus(
          receivedBytes: 0,
          speedBytesPerSecond: 0,
        ),
      );
      expect(spansText(stalled.detail), '0 MB of 11.28 GB');
    });

    test('reads no progress for an empty download', () async {
      stubOperations(
        operations,
        currentLibrary: ModelLibrary(
          status: const LibraryReady(),
          downloading: [
            modelDownload(
              totalBytes: 0,
              status: const DownloadTransferringStatus(receivedBytes: 0),
            ),
          ],
        ),
      );
      final row = (await pane().content('').first).rows.single;
      expect((row.progress! as PaneFraction).value, 0);
    });

    test('shows verifying', () async {
      final row = await downloadRow(
        const DownloadVerifyingStatus(receivedBytes: 1),
      );
      expect(row.glyph, '◉');
      expect(spansText(row.detail), 'Verifying checksum…');
      expect(actionLabels(row), ['Cancel']);
    });

    test('shows queued, with what it kept', () async {
      final fresh = await downloadRow(const DownloadQueuedStatus());
      expect(fresh.glyph, '◌');
      expect(spansText(fresh.detail), 'Queued');
      final kept = await downloadRow(
        const DownloadQueuedStatus(receivedBytes: 2820000000),
      );
      expect(spansText(kept.detail), 'Queued · 25% kept');
      expect(actionLabels(kept), ['Cancel']);
    });

    test('shows installed while the library picks it up', () async {
      final row = await downloadRow(const DownloadInstalledStatus());
      expect(row.glyph, '✓');
      expect(spansText(row.detail), 'Downloaded · adding it to the library…');
      expect(row.actions, isEmpty);
    });

    test('offers resuming a paused download', () async {
      final row = await downloadRow(
        const DownloadPausedStatus(receivedBytes: 4624800000),
      );
      expect(row.glyph, '◑');
      expect(
        spansText(row.detail),
        'Paused at 41% · [r] resumes where it stopped',
      );
      expect(actionLabels(row), ['Resume', 'Discard']);
    });

    test('offers retrying a download whose checksum failed', () async {
      final row = await downloadRow(
        const DownloadFailedStatus(
          reason: DownloadChecksumFailed('model.gguf'),
          receivedBytes: 1,
        ),
      );
      expect(
        spansText(row.detail),
        "Checksum didn't match for model.gguf · [r] downloads it again",
      );
      expect(actionLabels(row), ['Retry', 'Discard']);
    });

    test('offers retrying a failed download and says why', () async {
      final row = await downloadRow(
        const DownloadFailedStatus(
          reason: DownloadFailedEarlier('reset'),
          receivedBytes: 5640000000,
        ),
      );
      expect(spansText(row.detail), 'Failed at 50%: reset · [r] retries');
      expect(actionLabels(row), ['Retry', 'Discard']);
    });

    test('says when a finished download did not reach the library', () async {
      final failed = await downloadRow(
        const DownloadUnlistedStatus(UnlistedScanFailed('EIO')),
      );
      expect(
        spansText(failed.detail),
        'Downloaded, but scanning for it failed: EIO',
      );
      expect(actionLabels(failed), ['Discard']);
      final missing = await downloadRow(
        const DownloadUnlistedStatus(UnlistedFileMissing()),
      );
      expect(spansText(missing.detail), 'Downloaded, but its file is gone');
    });

    group('actions', () {
      final id = modelDownload().id;

      test('x cancels, or says it already stopped', () async {
        final cancel = actionOf(
          await downloadRow(const DownloadQueuedStatus()),
          const CharKey('x'),
        );
        expect(cancel.danger, isTrue);
        when(() => operations.cancel(id)).thenReturn(const CancelRequested());
        expect(await cancel.invoke(), isA<PaneStay>());
        when(() => operations.cancel(id)).thenReturn(const NothingToCancel());
        expect(
          (await cancel.invoke() as PaneRejected).reason,
          'That download is no longer running',
        );
      });

      test('r resumes, or says it is no longer waiting', () async {
        final resume = actionOf(
          await downloadRow(const DownloadPausedStatus(receivedBytes: 0)),
          const CharKey('r'),
        );
        when(() => operations.resume(id)).thenReturn(const ResumeQueued());
        expect(await resume.invoke(), isA<PaneStay>());
        when(() => operations.resume(id)).thenReturn(const NothingToResume());
        expect(
          (await resume.invoke() as PaneRejected).reason,
          'That download is no longer waiting',
        );
      });

      test('x discards, or says what it could not delete', () async {
        final discard = actionOf(
          await downloadRow(const DownloadPausedStatus(receivedBytes: 0)),
          const CharKey('x'),
        );
        expect(discard.danger, isTrue);
        when(
          () => operations.discard(id),
        ).thenAnswer((_) async => const DownloadDiscarded(freedBytes: 1));
        expect(await discard.invoke(), isA<PaneStay>());
        when(
          () => operations.discard(id),
        ).thenAnswer((_) async => const NothingToDiscard());
        expect(await discard.invoke(), isA<PaneStay>());
        when(() => operations.discard(id)).thenAnswer(
          (_) async => const DiscardFailed(
            path: '$homeDir/.bestie/x.part',
            error: 'EPERM',
          ),
        );
        expect(
          (await discard.invoke() as PaneRejected).reason,
          "Couldn't delete ~/.bestie/x.part: EPERM",
        );
      });
    });
  });

  group('a model row', () {
    test('marks the model in use and keeps Enter on it', () async {
      final content = await contentOf(
        ModelLibrary(
          status: const LibraryReady(),
          downloaded: [supportedModel()],
        ),
        running: 'qwen3-8b',
      );
      final row = content.rows.single;
      expect(row.glyph, '●');
      expect(row.glyphTone, PaneTone.success);
      expect(row.tint, PaneTint.primary);
      expect(spansText(row.trailing), 'Q4_K_M · 4.68 GB');
      expect(
        spansText(row.detail),
        'Downloaded from lmstudio-community/Qwen3-8B-GGUF',
      );
      expect(actionLabels(row), ['Using', 'Details', 'Delete']);
      expect(await actionOf(row, const PrimaryKey()).invoke(), isA<PaneStay>());
    });

    test('offers using, details and deleting a downloaded model', () async {
      final row = (await contentOf(
        ModelLibrary(
          status: const LibraryReady(),
          downloaded: [supportedModel()],
        ),
      )).rows.single;
      expect(row.glyph, '○');
      expect(row.tint, PaneTint.none);
      expect(actionLabels(row), ['Use', 'Details', 'Delete']);
    });

    test('shows where a model in your folders lives', () async {
      final row = (await contentOf(
        ModelLibrary(
          status: const LibraryReady(),
          inFolders: [
            supportedModel(
              source: const ScannedSource(root: '$homeDir/models'),
              path: '$homeDir/models/Llama-3.2-3B.gguf',
            ),
          ],
        ),
      )).rows.single;
      expect(spansText(row.detail), '~/models/Llama-3.2-3B.gguf');
      expect(actionLabels(row), ['Use', 'Details']);
    });

    test('mutes an unsupported model and says why', () async {
      final row = (await contentOf(
        ModelLibrary(
          status: const LibraryReady(),
          inFolders: [unsupportedModel()],
        ),
      )).rows.single;
      expect(row.glyph, '⊘');
      expect(row.labelTone, PaneTone.muted);
      expect(spansText(row.trailing), '1.97 GB');
      expect(
        spansText(row.detail),
        'Not supported yet: granitehybrid architecture',
      );
      expect(actionLabels(row), ['Details']);
    });
  });
}
