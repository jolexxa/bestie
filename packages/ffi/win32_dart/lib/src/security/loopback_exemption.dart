import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';

// NetworkIsolationSetAppContainerConfig returns ERROR_ACCESS_DENIED when
// Developer Mode is off — the whole reason `local`/loopback is gated. It is the
// clean branch: no registry read needed, the return code IS the Dev-Mode
// signal (confirmed both directions).
const int _errorAccessDenied = 5;

/// The live loopback-exemption list: the AppContainer SIDs allowed to reach
/// `127.0.0.1`. Loopback is never capability-gated, so this API is the only way
/// a confined process reaches localhost.
///
/// `NetworkIsolationSetAppContainerConfig` is a **full-list replace** of the
/// live (non-persistent) set — so reconcile with [list] first (merge on
/// acquire, remove on release) or a crash leaks an entry. It succeeds
/// unelevated **only with Developer Mode on**; off, [replaceAll] returns
/// [LoopbackExemptionDenied], which is how a caller learns to degrade the tier.
class LoopbackExemptions {
  /// Calls through [_bindings] for SID formatting and error messages; resolves
  /// the NetworkIsolation entry points from FirewallAPI.dll lazily.
  LoopbackExemptions(this._bindings);

  final WindowsBindings _bindings;

  late final DynamicLibrary _firewall = DynamicLibrary.open('FirewallAPI.dll');
  late final int Function(int, Pointer<SID_AND_ATTRIBUTES>) _set = _firewall
      .lookupFunction<
        Uint32 Function(Uint32, Pointer<SID_AND_ATTRIBUTES>),
        int Function(int, Pointer<SID_AND_ATTRIBUTES>)
      >('NetworkIsolationSetAppContainerConfig');
  late final int Function(Pointer<Uint32>, Pointer<Pointer<SID_AND_ATTRIBUTES>>)
  _get = _firewall
      .lookupFunction<
        Uint32 Function(Pointer<Uint32>, Pointer<Pointer<SID_AND_ATTRIBUTES>>),
        int Function(Pointer<Uint32>, Pointer<Pointer<SID_AND_ATTRIBUTES>>)
      >('NetworkIsolationGetAppContainerConfig');

  /// Replaces the entire live exemption set with [containerSids] (each an SDDL
  /// string). Pass the complete desired list — merge against [list] yourself.
  LoopbackExemptionSetResult replaceAll(List<String> containerSids) {
    final parsed = <Pointer<Void>>[];
    final array = containerSids.isEmpty
        ? nullptr
        : calloc<SID_AND_ATTRIBUTES>(containerSids.length);
    try {
      for (var i = 0; i < containerSids.length; i++) {
        final str = containerSids[i]
            .toNativeUtf16(allocator: calloc)
            .cast<WChar>();
        final out = calloc<Pointer<Void>>();
        try {
          if (_bindings.ConvertStringSidToSidW(str, out) == 0) {
            return LoopbackExemptionSetFailed(
              Win32Failure.fromLastError(_bindings, 'ConvertStringSidToSidW'),
            );
          }
          parsed.add(out.value);
          array[i]
            ..Sid = out.value
            ..Attributes = 0;
        } finally {
          calloc
            ..free(str)
            ..free(out);
        }
      }

      final rc = _set(containerSids.length, array);
      if (rc == 0) return const LoopbackExemptionSet();
      if (rc == _errorAccessDenied) return const LoopbackExemptionDenied();
      return LoopbackExemptionSetFailed(
        Win32Failure.fromCode(
          _bindings,
          'NetworkIsolationSetAppContainerConfig',
          rc,
        ),
      );
    } finally {
      parsed.forEach(_bindings.LocalFree);
      if (array != nullptr) calloc.free(array);
    }
  }

  /// The SDDL strings currently exempted. Used to merge on acquire and to sweep
  /// orphans (entries whose profile is gone) on teardown.
  LoopbackExemptionListResult list() {
    final countOut = calloc<Uint32>();
    final arrayOut = calloc<Pointer<SID_AND_ATTRIBUTES>>();
    try {
      final rc = _get(countOut, arrayOut);
      if (rc != 0) {
        return LoopbackExemptionListFailed(
          Win32Failure.fromCode(
            _bindings,
            'NetworkIsolationGetAppContainerConfig',
            rc,
          ),
        );
      }
      final count = countOut.value;
      final array = arrayOut.value;
      final sids = <String>[];
      for (var i = 0; i < count; i++) {
        final printed = calloc<Pointer<WChar>>();
        try {
          if (_bindings.ConvertSidToStringSidW(array[i].Sid, printed) != 0) {
            sids.add(printed.value.cast<Utf16>().toDartString());
            _bindings.LocalFree(printed.value.cast());
          }
        } finally {
          calloc.free(printed);
        }
      }
      // The Get buffer is `LocalAlloc`d — `LocalFree` is its deallocator. (Not
      // `NetworkIsolationFreeAppContainers`, which is for the unrelated
      // `INET_FIREWALL_APP_CONTAINER` array of the Enum API; passing this
      // SID_AND_ATTRIBUTES buffer to it corrupts the heap.)
      if (array != nullptr) _bindings.LocalFree(array.cast());
      return LoopbackExemptionListed(sids);
    } finally {
      calloc
        ..free(countOut)
        ..free(arrayOut);
    }
  }
}

sealed class LoopbackExemptionSetResult {
  const LoopbackExemptionSetResult();
}

final class LoopbackExemptionSet extends LoopbackExemptionSetResult {
  const LoopbackExemptionSet();
}

/// Developer Mode is off — the exemption cannot be programmed. The caller
/// degrades the network tier (`local` → ineligible, `all` → internet-only).
final class LoopbackExemptionDenied extends LoopbackExemptionSetResult {
  const LoopbackExemptionDenied();
}

final class LoopbackExemptionSetFailed extends LoopbackExemptionSetResult {
  const LoopbackExemptionSetFailed(this.failure);
  final Win32Failure failure;
}

sealed class LoopbackExemptionListResult {
  const LoopbackExemptionListResult();
}

final class LoopbackExemptionListed extends LoopbackExemptionListResult {
  const LoopbackExemptionListed(this.containerSids);
  final List<String> containerSids;
}

final class LoopbackExemptionListFailed extends LoopbackExemptionListResult {
  const LoopbackExemptionListFailed(this.failure);
  final Win32Failure failure;
}
