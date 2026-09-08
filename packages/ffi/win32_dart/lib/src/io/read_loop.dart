import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_handle.dart';

/// Starts [WindowsReadLoop]s.
class ReadLoops {
  /// Read loops resolve their own bindings inside the isolate, so this
  /// needs none.
  const ReadLoops();

  /// Starts a read loop on [handle], the read end of a pipe.
  WindowsReadLoop start(Win32Handle handle) {
    final receivePort = ReceivePort();
    final controller = StreamController<List<int>>(sync: true);
    final isolateReady = Completer<Isolate>();

    receivePort.listen((message) {
      if (controller.isClosed) return;
      if (message is List<int>) {
        controller.sink.add(message);
      } else if (message == null) {
        unawaited(controller.close());
        receivePort.close();
      }
    });

    unawaited(
      Isolate.spawn(
        _readLoopEntry,
        _ReadLoopArgs(receivePort.sendPort, handle.address),
      ).then(isolateReady.complete).catchError(isolateReady.completeError),
    );

    return WindowsReadLoop._(controller, receivePort, isolateReady);
  }
}

/// A background isolate doing a blocking `ReadFile(handle, buf)` loop,
/// forwarding each chunk to the main isolate over a [SendPort].
class WindowsReadLoop {
  WindowsReadLoop._(this._controller, this._receivePort, this._isolate);

  final StreamController<List<int>> _controller;
  final ReceivePort _receivePort;
  final Completer<Isolate> _isolate;

  /// Bytes as they arrive, closing on EOF.
  Stream<List<int>> get stream => _controller.stream;

  /// Closes the byte stream and kills the read isolate so its blocking
  /// `ReadFile` cannot pin a worker.
  Future<void> close() async {
    if (!_controller.isClosed) {
      final closing = _controller.close();
      if (_controller.hasListener) {
        await closing;
      } else {
        unawaited(closing);
      }
    }
    try {
      final isolate = await _isolate.future.timeout(
        const Duration(milliseconds: 100),
      );
      isolate.kill(priority: Isolate.immediate);
    } on Object {
      // Spawn never completed or already gone — fine.
    }
    _receivePort.close();
  }
}

class _ReadLoopArgs {
  _ReadLoopArgs(this.sendPort, this.handleAddress);
  final SendPort sendPort;
  final int handleAddress;
}

const int _readBufferSize = 4096;

// coverage:ignore-start
//
// Runs on a background isolate against the live kernel32 — it re-resolves
// its own bindings (isolates share no heap) and cannot be mocked.
void _readLoopEntry(_ReadLoopArgs args) {
  final kernel32 = WindowsBindings(DynamicLibrary.open('kernel32.dll'));
  final handle = Pointer<Void>.fromAddress(args.handleAddress);
  final buffer = calloc<Uint8>(_readBufferSize);
  final read = calloc<UnsignedLong>();
  try {
    while (true) {
      final ok = kernel32.ReadFile(
        handle,
        buffer.cast<Void>(),
        _readBufferSize,
        read,
        nullptr,
      );
      if (ok == 0 || read.value == 0) {
        // Zero return is EOF (the pipe's write end closed) or an error; a
        // zero count is EOF. Either ends the stream.
        args.sendPort.send(null);
        return;
      }
      args.sendPort.send(buffer.asTypedList(read.value).sublist(0));
    }
  } on Object {
    args.sendPort.send(null);
    rethrow;
  } finally {
    calloc
      ..free(buffer)
      ..free(read);
  }
}

// coverage:ignore-end
