import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// How a [Sid]'s backing memory must be released — the allocator differs by
/// source, and freeing with the wrong one corrupts the heap.
enum _SidRelease {
  /// `ConvertStringSidToSidW` allocates with `LocalAlloc` → `LocalFree`.
  localFree,

  /// `CreateAppContainerProfile` / `DeriveAppContainerSid…` → `FreeSid`.
  freeSid,
}

/// Owns a security identifier pointer and frees it exactly once.
class Sid {
  Sid._(this._bindings, this.pointer, this._release);

  final WindowsBindings _bindings;
  final _SidRelease _release;
  bool _closed = false;

  /// The `PSID` this owns, for `SECURITY_CAPABILITIES`, `TRUSTEE_W`, and the
  /// ACL calls.
  final Pointer<Void> pointer;

  /// The SDDL string form (`S-1-15-…`), or null if it cannot be rendered.
  String? asString() => Sids(_bindings).stringOf(pointer);

  /// Frees the SID with its source's allocator. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    switch (_release) {
      case _SidRelease.localFree:
        _bindings.LocalFree(pointer);
      case _SidRelease.freeSid:
        _bindings.FreeSid(pointer);
    }
  }
}

/// Converts and owns [Sid]s.
class Sids {
  /// Calls through the given Win32 bindings.
  const Sids(this._bindings);

  final WindowsBindings _bindings;

  /// Parses an SDDL string (`'S-1-15-3-1'`, …) into an owned [Sid].
  SidResult fromString(String sddl) {
    final str = sddl.toNativeUtf16(allocator: calloc).cast<WChar>();
    final out = calloc<Pointer<Void>>();
    try {
      if (_bindings.ConvertStringSidToSidW(str, out) == 0) {
        return SidFailed(
          Win32Failure.fromLastError(_bindings, 'ConvertStringSidToSidW'),
        );
      }
      return SidSucceeded(Sid._(_bindings, out.value, _SidRelease.localFree));
    } finally {
      calloc
        ..free(str)
        ..free(out);
    }
  }

  /// Wraps a SID the AppContainer APIs allocated, to be freed with `FreeSid`.
  Sid adoptAppContainerSid(Pointer<Void> pointer) =>
      Sid._(_bindings, pointer, _SidRelease.freeSid);

  /// The SDDL string form of a `PSID` this does not own, or null if it cannot
  /// be rendered.
  String? stringOf(Pointer<Void> pointer) {
    final out = calloc<Pointer<WChar>>();
    try {
      if (_bindings.ConvertSidToStringSidW(pointer, out) == 0) return null;
      final value = out.value.cast<Utf16>().toDartString();
      _bindings.LocalFree(out.value.cast());
      return value;
    } finally {
      calloc.free(out);
    }
  }
}

sealed class SidResult {
  const SidResult();
}

final class SidSucceeded extends SidResult {
  const SidSucceeded(this.sid);
  final Sid sid;
}

final class SidFailed extends SidResult {
  const SidFailed(this.failure);
  final Win32Failure failure;
}
