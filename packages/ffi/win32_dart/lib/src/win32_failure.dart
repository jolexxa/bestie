import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/text.dart';

/// Which error channel a [Win32Failure] code came from. Win32 error codes
/// and CRT errno values share the integer space but not the meaning.
enum Win32ErrorChannel {
  /// `GetLastError`.
  lastError,

  /// The CRT's `errno`.
  crtErrno,

  /// No code — the call reported failure without setting one.
  none,
}

/// Data carrier describing a failed Win32 or CRT call. Held by the `*Failed`
/// variant of every `win32_dart` operation result.
final class Win32Failure {
  const Win32Failure({
    required this.function,
    required this.code,
    required this.message,
    required this.channel,
  });

  /// Reads `GetLastError` and names it with `FormatMessageW`.
  factory Win32Failure.fromLastError(
    WindowsBindings bindings,
    String function,
  ) {
    final code = bindings.GetLastError();
    return Win32Failure(
      function: function,
      code: code,
      message: _formatMessage(bindings, code),
      channel: Win32ErrorChannel.lastError,
    );
  }

  /// Reads the CRT's `errno` and names it with `strerror_s`.
  factory Win32Failure.fromCrtErrno(
    WindowsBindings bindings,
    String function,
  ) {
    final code = _errno(bindings);
    return Win32Failure(
      function: function,
      code: code,
      message: _strerror(bindings, code),
      channel: Win32ErrorChannel.crtErrno,
    );
  }

  /// Names an explicit Win32 error code with `FormatMessageW` — for APIs like
  /// `GetNamedSecurityInfoW`, `SetEntriesInAclW`, and the NetworkIsolation
  /// calls that return a `DWORD` code directly instead of setting
  /// `GetLastError`.
  factory Win32Failure.fromCode(
    WindowsBindings bindings,
    String function,
    int code,
  ) => Win32Failure(
    function: function,
    code: code,
    message: _formatMessage(bindings, code),
    channel: Win32ErrorChannel.lastError,
  );

  /// A failure with no associated code.
  const Win32Failure.withoutCode(this.function, this.message)
    : code = 0,
      channel = Win32ErrorChannel.none;

  /// Name of the function that failed, e.g. `'CreateFileW'`.
  final String function;

  /// The error code, interpreted per [channel].
  final int code;

  /// Human-readable description of [code].
  final String message;

  /// Which error channel [code] came from.
  final Win32ErrorChannel channel;

  @override
  String toString() => switch (channel) {
    Win32ErrorChannel.lastError =>
      'Win32Failure($function, error=$code): $message',
    Win32ErrorChannel.crtErrno =>
      'Win32Failure($function, errno=$code): $message',
    Win32ErrorChannel.none => 'Win32Failure($function): $message',
  };

  static const _messageBufferLength = 512;

  static String _formatMessage(WindowsBindings bindings, int code) =>
      withWideBuffer(_messageBufferLength, (buffer) {
        final length = bindings.FormatMessageW(
          FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
          nullptr,
          code,
          0,
          buffer,
          _messageBufferLength,
          nullptr,
        );
        if (length == 0) return 'error $code';
        return readWideString(buffer).trim();
      });

  static int _errno(WindowsBindings bindings) {
    final value = calloc<Int>();
    try {
      return bindings.get_errno(value) == 0 ? value.value : 0;
    } finally {
      calloc.free(value);
    }
  }

  static String _strerror(WindowsBindings bindings, int code) =>
      withByteBuffer(_messageBufferLength, (buffer) {
        if (bindings.strerror_s(buffer, _messageBufferLength, code) != 0) {
          return 'errno $code';
        }
        return readByteString(buffer).trim();
      });
}
