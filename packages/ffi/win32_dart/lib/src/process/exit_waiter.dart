import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_handle.dart';

/// Starts [ProcessExitWaiter]s.
class ExitWaiters {
  /// Exit waiters resolve their own bindings inside the isolate, so this
  /// needs none.
  const ExitWaiters();

  /// Starts waiting on [process].
  ProcessExitWaiter start(Win32Handle process) {
    final receivePort = ReceivePort();
    final exitCode = Completer<int?>();
    final isolateReady = Completer<Isolate>();

    receivePort.listen((message) {
      if (!exitCode.isCompleted) exitCode.complete(message as int?);
      receivePort.close();
    });

    unawaited(
      Isolate.spawn(
        _waitEntry,
        _WaitArgs(receivePort.sendPort, process.address),
      ).then(isolateReady.complete).catchError(isolateReady.completeError),
    );

    return ProcessExitWaiter._(exitCode, receivePort, isolateReady);
  }
}

/// Waits for a child process to exit on a background isolate, so the main
/// isolate never blocks on `WaitForSingleObject`.
class ProcessExitWaiter {
  ProcessExitWaiter._(this._exitCode, this._receivePort, this._isolate);

  final Completer<int?> _exitCode;
  final ReceivePort _receivePort;
  final Completer<Isolate> _isolate;

  /// The child's exit code, or `null` if the wait or the status read failed.
  Future<int?> get exitCode => _exitCode.future;

  /// Kills the wait isolate. Call before closing the process handle, so a
  /// blocking `WaitForSingleObject` never outlives the handle it holds.
  Future<void> close() async {
    if (!_exitCode.isCompleted) _exitCode.complete(null);
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

class _WaitArgs {
  _WaitArgs(this.sendPort, this.handleAddress);
  final SendPort sendPort;
  final int handleAddress;
}

const int _waitObject0 = 0x00000000;

// coverage:ignore-start
//
// Runs on a background isolate against the live kernel32 — re-resolves its
// own bindings and cannot be mocked.
void _waitEntry(_WaitArgs args) {
  final kernel32 = WindowsBindings(DynamicLibrary.open('kernel32.dll'));
  final handle = Pointer<Void>.fromAddress(args.handleAddress);
  final code = calloc<UnsignedLong>();
  try {
    if (kernel32.WaitForSingleObject(handle, INFINITE) != _waitObject0) {
      args.sendPort.send(null);
      return;
    }
    if (kernel32.GetExitCodeProcess(handle, code) == 0) {
      args.sendPort.send(null);
      return;
    }
    args.sendPort.send(code.value);
  } finally {
    calloc.free(code);
  }
}

// coverage:ignore-end
