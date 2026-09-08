import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:posix_dart/posix_dart.dart';

/// Spawns a background isolate that does a blocking `read(masterFd,
/// buf, kReadBufSize)` loop, sending each chunk back to the main
/// isolate as a `List<int>` via [SendPort]. The OS wakes the isolate
/// when the master fd has data — no polling, no timers.
///
/// Returns a [Stream<List<int>>] that emits as bytes arrive, and
/// closes when `read` returns 0 (EOF, meaning the child closed its
/// stdout).
class PosixReadLoop {
  PosixReadLoop._(
    this._controller,
    this._receivePort,
    this._isolateCompleter,
  );

  /// Start a read loop for [masterFd]. Spawns a background isolate
  /// that does blocking reads on the master fd and forwards bytes
  /// back to the main isolate as [List<int>] chunks via [SendPort].
  factory PosixReadLoop.start(int masterFd) {
    final receivePort = ReceivePort();
    final controller = StreamController<List<int>>(sync: true);
    final isolateCompleter = Completer<Isolate>();

    receivePort.listen((msg) {
      // Late messages can arrive after close — drop them.
      if (controller.isClosed) return;
      if (msg is List<int>) {
        controller.sink.add(msg);
      } else if (msg == null) {
        // EOF marker.
        unawaited(controller.close());
        receivePort.close();
      }
    });

    // Hold the isolate handle so [close] can kill it — macOS keeps
    // a blocking `read()` asleep even after the fd is closed.
    unawaited(
      Isolate.spawn(
            _readLoopEntry,
            _ReadLoopArgs(receivePort.sendPort, masterFd),
          )
          .then(isolateCompleter.complete)
          .catchError(isolateCompleter.completeError),
    );

    return PosixReadLoop._(controller, receivePort, isolateCompleter);
  }

  final StreamController<List<int>> _controller;
  final ReceivePort _receivePort;
  final Completer<Isolate> _isolateCompleter;

  Stream<List<int>> get stream => _controller.stream;

  /// Tear down: close the byte stream, kill the read isolate so its
  /// blocking `read()` doesn't pin a worker indefinitely, then close
  /// the receive port. Caller is responsible for closing the master
  /// fd separately — we don't own it.
  Future<void> close() async {
    if (!_controller.isClosed) {
      // A single-subscription controller's close future only completes
      // once `done` is delivered — which needs a listener.
      final closing = _controller.close();
      if (_controller.hasListener) {
        await closing;
      } else {
        unawaited(closing);
      }
    }
    try {
      final iso = await _isolateCompleter.future.timeout(
        const Duration(milliseconds: 100),
      );
      iso.kill(priority: Isolate.immediate);
    } on Object {
      // Spawn never completed or already gone — fine.
    }
    _receivePort.close();
  }
}

class _ReadLoopArgs {
  _ReadLoopArgs(this.sendPort, this.masterFd);
  final SendPort sendPort;
  final int masterFd;
}

const int _kReadBufSize = 4096;

void _readLoopEntry(_ReadLoopArgs args) {
  // Re-resolve bindings inside the new isolate — Dart isolates
  // don't share heap, but `DynamicLibrary.process()` works the same
  // way in each.
  final buf = calloc<ffi.Uint8>(_kReadBufSize);
  try {
    while (true) {
      final n = posixBindings.read(
        args.masterFd,
        buf.cast<ffi.Void>(),
        _kReadBufSize,
      );
      if (n <= 0) {
        // 0 = EOF, <0 = error (probably EBADF when caller closes fd).
        args.sendPort.send(null);
        return;
      }
      args.sendPort.send(buf.asTypedList(n).sublist(0));
    }
  } on Object {
    args.sendPort.send(null);
    rethrow;
  } finally {
    calloc.free(buf);
  }
}
