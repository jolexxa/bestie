import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/security/sid.dart';

/// Owns a `SECURITY_CAPABILITIES` struct (and its capability array) naming the
/// AppContainer SID a child runs as plus the capabilities it is granted. Handed
/// to `CreateProcessW` via `ProcThreadAttribute.securityCapabilities`.
///
/// It references the [Sid]s' memory rather than copying, so the container SID
/// and every capability SID must outlive the spawn; this owns only the struct
/// and array it allocates.
class SecurityCapabilities {
  SecurityCapabilities._(this._struct, this._capabilities);

  /// Confines a child to [container], granting [capabilities] (each enabled).
  /// An empty capability set is the airtight floor — no network, workspace-only
  /// filesystem via the ACLs.
  factory SecurityCapabilities.forContainer(
    Sid container, {
    List<Sid> capabilities = const [],
  }) {
    Pointer<SID_AND_ATTRIBUTES> array = nullptr;
    if (capabilities.isNotEmpty) {
      array = calloc<SID_AND_ATTRIBUTES>(capabilities.length);
      for (var i = 0; i < capabilities.length; i++) {
        array[i]
          ..Sid = capabilities[i].pointer
          ..Attributes = SE_GROUP_ENABLED;
      }
    }
    final struct = calloc<SECURITY_CAPABILITIES>();
    struct.ref
      ..AppContainerSid = container.pointer
      ..Capabilities = array
      ..CapabilityCount = capabilities.length
      ..Reserved = 0;
    return SecurityCapabilities._(struct, array);
  }

  final Pointer<SECURITY_CAPABILITIES> _struct;
  final Pointer<SID_AND_ATTRIBUTES> _capabilities;
  bool _closed = false;

  /// The `SECURITY_CAPABILITIES` pointer, for the attribute's value slot.
  Pointer<SECURITY_CAPABILITIES> get pointer => _struct;

  /// The value's size in bytes, for `UpdateProcThreadAttribute`.
  int get size => sizeOf<SECURITY_CAPABILITIES>();

  /// Frees the struct and capability array. Idempotent. Does not free the SIDs
  /// it references — those are owned by their [Sid]s.
  void close() {
    if (_closed) return;
    _closed = true;
    calloc.free(_struct);
    if (_capabilities != nullptr) calloc.free(_capabilities);
  }
}
