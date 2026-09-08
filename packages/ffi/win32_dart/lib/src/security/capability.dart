import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/security/sid.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// The capability every bestie container carries to read broadly outside its
/// workspace.
const String bestieReadCapabilityName = 'bestie.read';

/// Derives the SID Windows assigns a named capability.
class Capabilities {
  /// Calls through the given Win32 bindings.
  const Capabilities(this._bindings);

  final WindowsBindings _bindings;

  /// The capability SID for [name] — a deterministic hash of the name, so the
  /// SID is stable across runs.
  SidResult sidFor(String name) {
    final capName = name.toNativeUtf16(allocator: calloc).cast<WChar>();
    final groupSids = calloc<Pointer<Pointer<Void>>>();
    final groupCount = calloc<UnsignedLong>();
    final capSids = calloc<Pointer<Pointer<Void>>>();
    final capCount = calloc<UnsignedLong>();
    final sddlOut = calloc<Pointer<WChar>>();
    try {
      final derived = _bindings.DeriveCapabilitySidsFromName(
        capName,
        groupSids,
        groupCount,
        capSids,
        capCount,
      );
      if (derived == 0) {
        return SidFailed(
          Win32Failure.fromLastError(_bindings, 'DeriveCapabilitySidsFromName'),
        );
      }
      try {
        if (capCount.value == 0 ||
            _bindings.ConvertSidToStringSidW(capSids.value[0], sddlOut) == 0) {
          return SidFailed(
            Win32Failure.fromLastError(_bindings, 'ConvertSidToStringSidW'),
          );
        }
        final sddl = sddlOut.value.cast<Utf16>().toDartString();
        _bindings.LocalFree(sddlOut.value.cast());
        return Sids(_bindings).fromString(sddl);
      } finally {
        _freeSidArray(groupSids.value, groupCount.value);
        _freeSidArray(capSids.value, capCount.value);
      }
    } finally {
      calloc
        ..free(capName)
        ..free(groupSids)
        ..free(groupCount)
        ..free(capSids)
        ..free(capCount)
        ..free(sddlOut);
    }
  }

  void _freeSidArray(Pointer<Pointer<Void>> array, int count) {
    if (array == nullptr) return;
    for (var i = 0; i < count; i++) {
      _bindings.LocalFree(array[i]);
    }
    _bindings.LocalFree(array.cast());
  }
}
