import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:intentions/intentions.dart';
import 'package:model_index_store/src/download_ledger.dart';
import 'package:model_index_store/src/json_file.dart';
import 'package:model_index_store/src/store_result.dart';

/// The download ledger at [path], which lets downloads outlive the app and
/// remembers where each downloaded model came from.
///
/// One process at a time should change it: [lock] takes an advisory lock on
/// a file beside it, held until [unlock].
@dataSource
class DownloadLedgerStore {
  DownloadLedgerStore({
    required this.path,
    FileSystem fileSystem = const LocalFileSystem(),
  }) : _fileSystem = fileSystem;

  final String path;
  final FileSystem _fileSystem;
  RandomAccessFile? _lock;

  String get lockPath => _fileSystem.path.join(
    _fileSystem.path.dirname(path),
    DownloadLedger.lockFileName,
  );

  Future<StoreReadResult<DownloadLedger>> read() =>
      readJsonFile(_fileSystem, path, DownloadLedgerMapper.fromJson);

  Future<StoreWriteResult> write(DownloadLedger ledger) =>
      writeJsonFile(_fileSystem, path, ledger.toMap());

  /// Moves the ledger to `<path>.corrupt-<at>`, keeping it for a person to
  /// look at while a fresh ledger takes its place.
  Future<StoreSetAsideResult> setAside(DateTime at) async {
    final stamp = at.toUtc().toIso8601String().replaceAll(':', '-');
    try {
      final moved = await _fileSystem.file(path).rename('$path.corrupt-$stamp');
      return StoreSetAside(moved.path);
    } on FileSystemException catch (error) {
      return StoreSetAsideFailed('${error.message}: $path');
    }
  }

  /// Takes the lock without waiting for it. Locking again while holding it
  /// changes nothing.
  Future<LedgerLockResult> lock() async {
    if (_lock != null) return const LedgerLockAcquired();
    final RandomAccessFile file;
    try {
      final lockFile = _fileSystem.file(lockPath);
      await lockFile.parent.create(recursive: true);
      file = await lockFile.open(mode: FileMode.append);
    } on FileSystemException catch (error) {
      return LedgerLockFailed('${error.message}: $lockPath');
    }
    try {
      _lock = await file.lock();
      return const LedgerLockAcquired();
    } on FileSystemException {
      await file.close();
      return const LedgerLockHeld();
    }
  }

  Future<void> unlock() async {
    final lock = _lock;
    _lock = null;
    await lock?.close();
  }
}
