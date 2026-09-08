import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/process/attribute_list.dart';
import 'package:win32_dart/src/win32_failure.dart';
import 'package:win32_dart/src/win32_handle.dart';

/// Launches children with `CreateProcessW`.
class ChildProcesses {
  /// Calls through the given Win32 bindings.
  const ChildProcesses(this._bindings);

  final WindowsBindings _bindings;

  /// Launches [commandLine] with [attributeList] attached, optionally in
  /// [workingDirectory] (the child's initial current directory).
  ChildProcessStartResult start({
    required String commandLine,
    required AttributeList attributeList,
    Map<String, String>? environment,
    String? workingDirectory,
    bool inheritHandles = false,
    Win32Handle? stdInput,
    Win32Handle? stdOutput,
    Win32Handle? stdError,
  }) {
    final startupInfo = calloc<STARTUPINFOEXW>();
    startupInfo.ref.StartupInfo.cb = sizeOf<STARTUPINFOEXW>();
    startupInfo.ref.lpAttributeList = attributeList.pointer;
    startupInfo.ref.StartupInfo.dwFlags |= STARTF_USESTDHANDLES;
    // calloc zeroed the struct, so unset std handles are already null — the
    // ConPTY case wants exactly that.
    if (stdInput != null) startupInfo.ref.StartupInfo.hStdInput = stdInput;
    if (stdOutput != null) startupInfo.ref.StartupInfo.hStdOutput = stdOutput;
    if (stdError != null) startupInfo.ref.StartupInfo.hStdError = stdError;

    final command = commandLine.toNativeUtf16(allocator: calloc);
    final envBlock = environment == null
        ? nullptr
        : _encodeEnvironment(environment);
    final cwd = workingDirectory == null
        ? nullptr
        : workingDirectory.toNativeUtf16(allocator: calloc);
    final info = calloc<PROCESS_INFORMATION>();
    try {
      final flags =
          EXTENDED_STARTUPINFO_PRESENT |
          (environment == null ? 0 : CREATE_UNICODE_ENVIRONMENT);
      final ok = _bindings.CreateProcessW(
        nullptr,
        command.cast<WChar>(),
        nullptr,
        nullptr,
        inheritHandles ? 1 : 0,
        flags,
        envBlock.cast<Void>(),
        cwd.cast<WChar>(),
        startupInfo.cast<STARTUPINFOW>(),
        info,
      );
      if (ok == 0) {
        return ChildProcessStartFailed(
          Win32Failure.fromLastError(_bindings, 'CreateProcessW'),
        );
      }
      return ChildProcessStartSucceeded(
        ChildProcess._(
          _bindings,
          Win32Handle(info.ref.hProcess),
          Win32Handle(info.ref.hThread),
          info.ref.dwProcessId,
        ),
      );
    } finally {
      calloc
        ..free(startupInfo)
        ..free(command)
        ..free(info);
      if (envBlock != nullptr) calloc.free(envBlock);
      if (cwd != nullptr) calloc.free(cwd);
    }
  }
}

/// A child launched with `CreateProcessW`, owning its process and thread
/// handles and closing each once.
class ChildProcess {
  ChildProcess._(this._bindings, this._process, this._thread, this.pid);

  final WindowsBindings _bindings;
  final Win32Handle _process;
  final Win32Handle _thread;
  bool _closed = false;

  /// The child's process id.
  final int pid;

  /// The process handle, for waiting on exit.
  Win32Handle get processHandle => _process;

  /// Terminates the child with [exitCode]. Windows has no graceful signal —
  /// this is the only stop — so a running child ends abruptly.
  ChildTerminateResult terminate({int exitCode = 1}) {
    if (_bindings.TerminateProcess(_process, exitCode) == 0) {
      return ChildTerminateFailed(
        Win32Failure.fromLastError(_bindings, 'TerminateProcess'),
      );
    }
    return const ChildTerminateSucceeded();
  }

  /// Closes the process and thread handles. Does NOT stop the child — call
  /// [terminate] first if you need it dead. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    _bindings
      ..CloseHandle(_process)
      ..CloseHandle(_thread);
  }
}

/// Encodes [environment] as a UTF-16 block of `key=value\0` strings with a
/// trailing terminator, as `CREATE_UNICODE_ENVIRONMENT` expects.
Pointer<Uint16> _encodeEnvironment(Map<String, String> environment) {
  final units = <int>[];
  for (final entry in environment.entries) {
    units
      ..addAll('${entry.key}=${entry.value}'.codeUnits)
      ..add(0);
  }
  units.add(0);
  final block = calloc<Uint16>(units.length);
  block.asTypedList(units.length).setAll(0, units);
  return block;
}

sealed class ChildProcessStartResult {
  const ChildProcessStartResult();
}

final class ChildProcessStartSucceeded extends ChildProcessStartResult {
  const ChildProcessStartSucceeded(this.process);
  final ChildProcess process;
}

final class ChildProcessStartFailed extends ChildProcessStartResult {
  const ChildProcessStartFailed(this.failure);
  final Win32Failure failure;
}

sealed class ChildTerminateResult {
  const ChildTerminateResult();
}

final class ChildTerminateSucceeded extends ChildTerminateResult {
  const ChildTerminateSucceeded();
}

final class ChildTerminateFailed extends ChildTerminateResult {
  const ChildTerminateFailed(this.failure);
  final Win32Failure failure;
}
