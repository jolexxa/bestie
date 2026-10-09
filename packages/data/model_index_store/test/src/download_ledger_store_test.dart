import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:test/test.dart';

const _path = '/home/me/.bestie/models/downloads.json';
const _lockPath = '/home/me/.bestie/models/.downloads.lock';

class _MockFileSystem extends Mock implements FileSystem {}

class _MockFile extends Mock implements File {}

class _MockDirectory extends Mock implements Directory {}

class _MockRandomAccessFile extends Mock implements RandomAccessFile {}

const _ledger = DownloadLedger(
  version: DownloadLedger.currentVersion,
  downloads: [
    DownloadRecord(
      id: 'Qwen/Qwen3-1.7B-GGUF:Q4_K_M',
      repo: 'Qwen/Qwen3-1.7B-GGUF',
      revision: 'abc123',
      quant: 'Q4_K_M',
      files: [
        DownloadRecordFile(
          path: 'Qwen3-1.7B-Q4_K_M.gguf',
          url:
              'https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/abc123/Qwen3-1.7B-Q4_K_M.gguf',
          bytes: 1107409472,
          sha256: 'feed',
        ),
      ],
      status: DownloadRecordStatus.paused,
      receivedBytes: 4096,
    ),
    DownloadRecord(
      id: 'org/split-GGUF:Q8_0',
      repo: 'org/split-GGUF',
      quant: 'Q8_0',
      files: [
        DownloadRecordFile(
          path: 'Q8_0/m-00001-of-00002.gguf',
          url: 'a',
          bytes: 1,
        ),
        DownloadRecordFile(
          path: 'Q8_0/m-00002-of-00002.gguf',
          url: 'b',
          bytes: 2,
        ),
      ],
      status: DownloadRecordStatus.failed,
      failure: 'connection reset',
    ),
  ],
);

void main() {
  late MemoryFileSystem fileSystem;
  late DownloadLedgerStore store;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    store = DownloadLedgerStore(path: _path, fileSystem: fileSystem);
  });

  group('DownloadLedgerStore', () {
    test('reads nothing before the first write', () async {
      expect(await store.read(), isA<StoreAbsent<DownloadLedger>>());
    });

    test('round-trips every record field', () async {
      expect(await store.write(_ledger), isA<StoreWritten>());

      final read = await store.read();

      expect((read as StoreLoaded<DownloadLedger>).value, _ledger);
      expect(
        fileSystem.directory(fileSystem.path.dirname(_path)).listSync(),
        hasLength(1),
      );
    });

    test('writes snake case with status names', () async {
      await store.write(_ledger);

      final json = fileSystem.file(_path).readAsStringSync();

      expect(json, contains('"received_bytes": 4096'));
      expect(json, contains('"status": "paused"'));
    });

    test('defaults missing optional fields', () {
      final record = DownloadRecordMapper.fromJson(
        '{"id":"a/b:Q4_0","repo":"a/b","quant":"Q4_0","files":[],'
        '"status":"pending"}',
      );

      expect(record.receivedBytes, 0);
      expect(record.revision, isNull);
      expect(record.failure, isNull);
    });

    group('setAside', () {
      test('moves the ledger out of the way, keeping it', () async {
        fileSystem.file(_path)
          ..createSync(recursive: true)
          ..writeAsStringSync('{nope');

        final result = await store.setAside(DateTime.utc(2026, 10, 4, 3, 14));

        const movedTo = '$_path.corrupt-2026-10-04T03-14-00.000Z';
        expect((result as StoreSetAside).movedTo, movedTo);
        expect(fileSystem.file(movedTo).readAsStringSync(), '{nope');
        expect(await store.read(), isA<StoreAbsent<DownloadLedger>>());
      });

      test('says why the ledger could not be moved', () async {
        final result = await store.setAside(DateTime.utc(2026));

        expect((result as StoreSetAsideFailed).reason, endsWith(_path));
      });
    });

    group('lock', () {
      late _MockFileSystem lockingSystem;
      late _MockFile lockFile;
      late _MockRandomAccessFile handle;
      late DownloadLedgerStore locking;

      setUpAll(() => registerFallbackValue(FileMode.append));

      setUp(() {
        lockingSystem = _MockFileSystem();
        lockFile = _MockFile();
        handle = _MockRandomAccessFile();
        final folder = _MockDirectory();
        when(() => lockingSystem.path).thenReturn(fileSystem.path);
        when(() => lockingSystem.file(_lockPath)).thenReturn(lockFile);
        when(() => lockFile.parent).thenReturn(folder);
        when(
          () => folder.create(recursive: true),
        ).thenAnswer((_) async => folder);
        when(
          () => lockFile.open(mode: any(named: 'mode')),
        ).thenAnswer((_) async => handle);
        when(handle.lock).thenAnswer((_) async => handle);
        when(handle.close).thenAnswer((_) async {});
        locking = DownloadLedgerStore(path: _path, fileSystem: lockingSystem);
      });

      test('sits beside the ledger', () {
        expect(locking.lockPath, _lockPath);
      });

      test('is taken once and held until unlocked', () async {
        expect(await locking.lock(), isA<LedgerLockAcquired>());
        expect(await locking.lock(), isA<LedgerLockAcquired>());

        verify(() => lockFile.open(mode: FileMode.append)).called(1);
        verifyNever(handle.close);

        await locking.unlock();
        await locking.unlock();

        verify(handle.close).called(1);
      });

      test('is held by another process when it cannot be taken', () async {
        when(handle.lock).thenThrow(const FileSystemException('busy'));

        expect(await locking.lock(), isA<LedgerLockHeld>());
        verify(handle.close).called(1);
      });

      test('says why the lock file could not be opened', () async {
        when(
          () => lockFile.open(mode: any(named: 'mode')),
        ).thenThrow(const FileSystemException('Permission denied'));

        final result = await locking.lock();

        expect(
          (result as LedgerLockFailed).reason,
          'Permission denied: $_lockPath',
        );
      });
    });

    test('names its files and starts empty', () {
      expect(DownloadLedger.fileName, 'downloads.json');
      expect(DownloadLedger.lockFileName, '.downloads.lock');
      expect(DownloadLedger.empty.downloads, isEmpty);
      expect(DownloadLedger.empty.version, DownloadLedger.currentVersion);
    });
  });
}
