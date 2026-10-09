import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

const _downloaded = DownloadedSource(
  downloadId: 'Qwen/Qwen3-1.7B-GGUF:Q4_K_M',
  repo: 'Qwen/Qwen3-1.7B-GGUF',
  revision: 'abc123',
  file: 'Qwen3-1.7B-Q4_K_M.gguf',
);

ModelDownload _download(String id, ModelDownloadStatus status) => ModelDownload(
  id: id,
  repo: 'Qwen/Qwen3-1.7B-GGUF',
  quant: 'Q4_K_M',
  totalBytes: 100,
  status: status,
);

void main() {
  group('reasons', () {
    test('carry the data a caller words them from', () {
      const UnsupportedReason architecture = ArchitectureUnsupported('gemma4v');
      const UnrunnableReason template = TemplateUnrecognized('qwen2');

      expect((architecture as ProfileUnavailable).architecture, 'gemma4v');
      expect((template as ProfileUnavailable).architecture, 'qwen2');
      expect(const QuantUnsupported(33).fileType, 33);
      expect(
        const MetadataMissing('general.file_type').key,
        'general.file_type',
      );
      expect(const HeaderUnreadable('bad magic').reason, 'bad magic');
      expect(const ShardsMissing(found: 2, expected: 3).found, 2);
      expect(const NoSupportedQuants(['NVFP4']).labels, ['NVFP4']);
      expect(const NoGgufFiles(), isA<UnrunnableReason>());
      expect(const NotAChatModel('text-ranking').task, 'text-ranking');
    });
  });

  group('ModelSource', () {
    test('records downloads with their repo, revision and first file', () {
      expect(
        _downloaded.provenance,
        const ModelDownloaded(
          repo: 'Qwen/Qwen3-1.7B-GGUF',
          revision: 'abc123',
          file: 'Qwen3-1.7B-Q4_K_M.gguf',
        ),
      );
    });

    test('records scanned models by their folder, leaving guesses out', () {
      const source = ScannedSource(
        root: '/models',
        inferredRepo: InferredRepo(repo: 'org/repo', revision: 'r1'),
      );

      expect(source.provenance, const ModelScanned(root: '/models'));
      expect(source.inferredRepo!.repo, 'org/repo');
      expect(source.inferredRepo!.revision, 'r1');
    });

    test('records untracked files by the models folder, keeping guesses', () {
      const inferred = InferredRepo(repo: 'org/repo');

      final untracked = const ScannedSource(
        root: '/models',
        inferredRepo: inferred,
      ).untracked;

      expect(untracked.root, '/models');
      expect(untracked.inferredRepo, inferred);
      expect(untracked.provenance, const ModelScanned(root: '/models'));
    });
  });

  group('SupportedModel', () {
    test('runs with its detected reasoning until overridden', () {
      final model = supportedModel();

      expect(model.reasoning, const ModelReasoningToggle());

      final overridden = model.withReasoningOverride(
        const ModelReasoningNone(),
      );
      expect(overridden.reasoning, const ModelReasoningNone());
      expect(overridden.detectedReasoning, const ModelReasoningToggle());
      expect(
        overridden.withReasoningOverride(null).reasoning,
        const ModelReasoningToggle(),
      );
    });

    test('keeps everything else when its source changes', () {
      final model = supportedModel().withReasoningOverride(
        const ModelReasoningAlways(),
      );

      final moved = model.withSource(_downloaded);

      expect(moved.source, _downloaded);
      expect(moved.reasoning, const ModelReasoningAlways());
      expect(moved.id, model.id);
      expect(moved.quant, model.quant);
      expect(moved.parameterCount, model.parameterCount);
    });

    test('becomes the index entry the server loads', () {
      final model = supportedModel(
        source: _downloaded,
      ).withReasoningOverride(const ModelReasoningNone());

      expect(
        model.indexEntry,
        const ModelIndexEntry(
          localId: 'qwen3-1.7b-q4_k_m-1a2b3c4d',
          path: '/models/Qwen3-1.7B-Q4_K_M.gguf',
          displayName: 'Qwen3 1.7B',
          profileId: ModelProfileId.qwen3,
          architecture: 'qwen3',
          fileType: 'Q4_K_M',
          sizeBytes: 1000,
          parameterCount: 1700,
          trainedContextLength: 40960,
          reasoning: ModelReasoningNone(),
          defaultSampling: ModelSamplingDefaults(temperature: 0.6),
          provenance: ModelDownloaded(
            repo: 'Qwen/Qwen3-1.7B-GGUF',
            revision: 'abc123',
            file: 'Qwen3-1.7B-Q4_K_M.gguf',
          ),
          fingerprint: '1a2b3c4d',
        ),
      );
    });
  });

  group('UnsupportedModel', () {
    test('never reaches the index and ignores reasoning choices', () {
      final model = unsupportedModel();

      expect(model.indexEntry, isNull);
      expect(
        model.withReasoningOverride(const ModelReasoningNone()),
        same(model),
      );
    });

    test('keeps its reason when its source changes', () {
      final moved = unsupportedModel().withSource(_downloaded);

      expect(moved.source, _downloaded);
      expect(moved.reason, isA<ArchitectureUnsupported>());
      expect(moved.displayName, 'Granite-4.0-H-Micro');
    });
  });

  group('ModelDownload', () {
    test('needs attention only once it waits on the user', () {
      expect(const DownloadQueuedStatus().needsAttention, isFalse);
      expect(const DownloadQueuedStatus().receivedBytes, 0);
      expect(
        const DownloadTransferringStatus(receivedBytes: 1).needsAttention,
        isFalse,
      );
      expect(
        const DownloadVerifyingStatus(receivedBytes: 1).needsAttention,
        isFalse,
      );
      expect(const DownloadInstalledStatus().needsAttention, isFalse);
      expect(
        const DownloadUnlistedStatus(UnlistedFileMissing()).needsAttention,
        isTrue,
      );
      expect(
        const DownloadPausedStatus(receivedBytes: 1).needsAttention,
        isTrue,
      );
      expect(
        const DownloadFailedStatus(
          reason: DownloadFailedEarlier('x'),
          receivedBytes: 1,
        ).needsAttention,
        isTrue,
      );
    });

    test('carries what it is', () {
      final download = _download('a', const DownloadQueuedStatus());

      expect(download.id, 'a');
      expect(download.repo, 'Qwen/Qwen3-1.7B-GGUF');
      expect(download.quant, 'Q4_K_M');
      expect(download.totalBytes, 100);
    });
  });

  group('ModelLibrary', () {
    test('starts loading, so it never reads as empty too soon', () {
      expect(ModelLibrary.loading.isEmpty, isTrue);
      expect(ModelLibrary.loading.scanning, isFalse);
      expect(ModelLibrary.loading.status, isA<LibraryLoading>());
      expect(ModelLibrary.loading.downloadsStatus, isA<DownloadsStarting>());
    });

    test('is not empty while anything is listed', () {
      final download = _download('a', const DownloadQueuedStatus());
      expect(ModelLibrary(downloading: [download]).isEmpty, isFalse);
      expect(ModelLibrary(needsAttention: [download]).isEmpty, isFalse);
      expect(ModelLibrary(downloaded: [supportedModel()]).isEmpty, isFalse);
      expect(ModelLibrary(inFolders: [unsupportedModel()]).isEmpty, isFalse);
    });

    test('finds models by id and lists the runnable ones', () {
      final downloaded = supportedModel(id: 'a', source: _downloaded);
      final folder = supportedModel(id: 'b');
      final unsupported = unsupportedModel(id: 'c');
      final library = ModelLibrary(
        downloaded: [downloaded],
        inFolders: [folder, unsupported],
      );

      expect(library.models, [downloaded, folder, unsupported]);
      expect(library.runnable, [downloaded, folder]);
      expect(library.modelById('c'), same(unsupported));
      expect(library.modelById('missing'), isNull);
    });

    test('lets downloads change only once the ledger is usable', () {
      expect(const DownloadsStarting().writable, isFalse);
      expect(const DownloadsManagedElsewhere().writable, isFalse);
      expect(const DownloadsLedgerUnreadable('locked').writable, isFalse);
      expect(const DownloadsReady().writable, isTrue);
      expect(const DownloadsLedgerNotSaved('disk full').writable, isTrue);
      expect(
        const DownloadsLedgerSetAside(reason: 'bad', movedTo: '/x').writable,
        isTrue,
      );
    });
  });

  group('RepoQuant', () {
    RepoQuant quant() => RepoQuant(
      repo: 'org/split-GGUF',
      revision: 'abc',
      label: 'Q4_K_XL',
      type: QuantType.q4KMedium,
      inLibrary: false,
      files: [
        RepoFile(
          path: 'UD-Q4_K_XL/a-00001-of-00002.gguf',
          url: Uri.parse('https://hf/a'),
          sizeBytes: 3,
        ),
        RepoFile(
          path: 'UD-Q4_K_XL/a-00002-of-00002.gguf',
          url: Uri.parse('https://hf/b'),
          sizeBytes: 4,
        ),
      ],
    );

    test('adds up its files and names its download by its first file', () {
      expect(
        quant().downloadId,
        'org/split-GGUF:UD-Q4_K_XL/a-00001-of-00002.gguf',
      );
      expect(quant().sizeBytes, 7);
      expect(quant().tier, QualityTier.great);
    });

    test('reads as in the library when its download is', () {
      expect(quant().within({quant().downloadId}).inLibrary, isTrue);
      expect(quant().within({'org/split-GGUF:Q4_K_XL'}).inLibrary, isFalse);
    });
  });

  group('results', () {
    test('carry what callers need', () {
      expect(const DownloadAccepted('a').downloadId, 'a');
      expect(const DownloadAlreadyQueued('b').downloadId, 'b');
      expect(const DownloadTargetOccupied('c', path: '/p').path, '/p');
      expect(
        const DownloadRejected('d', reason: NoDownloadFiles()).reason,
        isA<NoDownloadFiles>(),
      );
      expect(const DownloadsUnavailable('e').downloadId, 'e');
      expect(const ModelDeleted(freedBytes: 9).freedBytes, 9);
      expect(const DeleteRefusedScanned(root: '/m').root, '/m');
      expect(const DeleteRefusedUntracked(path: '/m/a').path, '/m/a');
      expect(const DeleteFailed(path: '/p', error: 'busy').error, 'busy');
      expect(const DownloadDiscarded(freedBytes: 3).freedBytes, 3);
      expect(const DiscardFailed(path: '/p', error: 'busy').path, '/p');
      expect(const RepoNotFound(repo: 'a/b').repo, 'a/b');
      expect(
        const RepoLookupFailed(repo: 'a/b', message: 'offline').message,
        'offline',
      );
      expect(
        const RepoUnrunnable(repo: 'a/b', reason: NoGgufFiles()).reason,
        isA<NoGgufFiles>(),
      );
      expect(const LedgerRestored().dropped, isEmpty);
      expect(
        const DroppedDownload(
          downloadId: 'f',
          reason: InvalidRepoId('x'),
        ).reason,
        isA<InvalidRepoId>(),
      );
    });
  });
}
