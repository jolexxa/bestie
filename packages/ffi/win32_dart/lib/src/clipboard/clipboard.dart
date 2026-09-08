import 'dart:ffi';

import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';
import 'package:win32_dart/src/win32_handle.dart';

/// Opens [ClipboardSession]s.
class Clipboard {
  Clipboard(this._bindings);

  final WindowsBindings _bindings;

  /// Opens the clipboard, which stays held until the session is closed.
  ///
  /// Fails with `ERROR_ACCESS_DENIED` while another process has it open.
  /// Retrying is the caller's call to make; this stays synchronous.
  ClipboardOpenResult open() {
    if (_bindings.OpenClipboard(nullptr) == 0) {
      return ClipboardOpenFailed(
        Win32Failure.fromLastError(_bindings, 'OpenClipboard'),
      );
    }
    return ClipboardOpenSucceeded(ClipboardSession._(_bindings));
  }
}

/// The clipboard, held open for the length of one exchange and closed
/// exactly once.
///
/// The clipboard is a process-wide exclusive resource: while this session is
/// open no other process can read or write it, so hold it briefly.
class ClipboardSession {
  ClipboardSession._(this._bindings);

  final WindowsBindings _bindings;
  bool _closed = false;

  /// Whether [close] has already succeeded.
  bool get isClosed => _closed;

  /// Replaces the clipboard's contents with [text] as `CF_UNICODETEXT`.
  ClipboardWriteResult writeUnicodeText(String text) {
    if (_closed) {
      return const ClipboardWriteFailed(
        Win32Failure.withoutCode(
          'SetClipboardData',
          'clipboard session is closed',
        ),
      );
    }

    // Ownership of the clipboard transfers to this process here, which is
    // what makes the SetClipboardData below legal.
    if (_bindings.EmptyClipboard() == 0) {
      return ClipboardWriteFailed(
        Win32Failure.fromLastError(_bindings, 'EmptyClipboard'),
      );
    }

    final units = text.codeUnits;
    final block = Win32Handle(
      _bindings.GlobalAlloc(
        GMEM_MOVEABLE,
        (units.length + 1) * sizeOf<Uint16>(),
      ),
    );
    if (!block.isValid) {
      return ClipboardWriteFailed(
        Win32Failure.fromLastError(_bindings, 'GlobalAlloc'),
      );
    }

    final memory = _bindings.GlobalLock(block);
    if (memory == nullptr) {
      final failure = Win32Failure.fromLastError(_bindings, 'GlobalLock');
      _bindings.GlobalFree(block);
      return ClipboardWriteFailed(failure);
    }

    // GMEM_MOVEABLE does not zero the block, so the terminator is written
    // rather than assumed.
    memory.cast<Uint16>().asTypedList(units.length + 1)
      ..setAll(0, units)
      ..[units.length] = 0;

    // Zero means both "the lock count reached zero", which is the normal
    // outcome, and "the call failed". Telling them apart would take a
    // GetLastError read and change nothing that follows.
    _bindings.GlobalUnlock(block);

    // A successful SetClipboardData hands the block to the system, so past
    // this point freeing it would free memory we no longer own.
    final stored = Win32Handle(
      _bindings.SetClipboardData(CF_UNICODETEXT, block),
    );
    if (!stored.isValid) {
      final failure = Win32Failure.fromLastError(_bindings, 'SetClipboardData');
      _bindings.GlobalFree(block);
      return ClipboardWriteFailed(failure);
    }

    return const ClipboardWriteSucceeded();
  }

  /// Releases the clipboard. Nothing written becomes visible to other
  /// processes until this succeeds. Closing an already-closed session does
  /// nothing and succeeds.
  ClipboardCloseResult close() {
    if (_closed) return const ClipboardCloseSucceeded();
    if (_bindings.CloseClipboard() == 0) {
      return ClipboardCloseFailed(
        Win32Failure.fromLastError(_bindings, 'CloseClipboard'),
      );
    }
    _closed = true;
    return const ClipboardCloseSucceeded();
  }
}

sealed class ClipboardOpenResult {
  const ClipboardOpenResult();
}

final class ClipboardOpenSucceeded extends ClipboardOpenResult {
  const ClipboardOpenSucceeded(this.session);
  final ClipboardSession session;
}

final class ClipboardOpenFailed extends ClipboardOpenResult {
  const ClipboardOpenFailed(this.failure);
  final Win32Failure failure;
}

sealed class ClipboardWriteResult {
  const ClipboardWriteResult();
}

final class ClipboardWriteSucceeded extends ClipboardWriteResult {
  const ClipboardWriteSucceeded();
}

final class ClipboardWriteFailed extends ClipboardWriteResult {
  const ClipboardWriteFailed(this.failure);
  final Win32Failure failure;
}

sealed class ClipboardCloseResult {
  const ClipboardCloseResult();
}

final class ClipboardCloseSucceeded extends ClipboardCloseResult {
  const ClipboardCloseSucceeded();
}

final class ClipboardCloseFailed extends ClipboardCloseResult {
  const ClipboardCloseFailed(this.failure);
  final Win32Failure failure;
}
