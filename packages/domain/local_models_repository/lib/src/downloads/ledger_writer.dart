import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/downloads/download_queue.dart';
import 'package:model_index_store/model_index_store.dart';

/// Saves the download ledger. Saves asked for together become one write,
/// and only the latest ledger is ever written. A failed write is retried
/// after [retryDelay], or sooner when another save is asked for.
@PartOf(DownloadQueue)
class LedgerWriter {
  LedgerWriter(
    this._store, {
    this.retryDelay = const Duration(seconds: 5),
  });

  final DownloadLedgerStore _store;
  final Duration retryDelay;
  final _written = StreamController<StoreWriteResult>.broadcast(sync: true);

  /// The newest ledger not yet on disk.
  DownloadLedger? _unsaved;
  Future<void>? _flush;
  Timer? _retry;

  /// How each write went.
  Stream<StoreWriteResult> get written => _written.stream;

  void save(DownloadLedger ledger) {
    _unsaved = ledger;
    _flush ??= Future.microtask(_writeUnsaved);
  }

  /// Waits for the write under way, without retrying a failed one.
  Future<void> close() async {
    _retry?.cancel();
    await _flush;
    await _written.close();
  }

  Future<void> _writeUnsaved() async {
    for (var ledger = _unsaved; ledger != null; ledger = _unsaved) {
      _unsaved = null;
      final result = await _store.write(ledger);
      _written.add(result);
      if (result is StoreWriteFailed) {
        _unsaved ??= ledger;
        _retry?.cancel();
        _retry = Timer(retryDelay, _retryUnsaved);
        break;
      }
    }
    _flush = null;
  }

  void _retryUnsaved() {
    if (_unsaved case final ledger?) save(ledger);
  }
}
