import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/console/pseudo_console.dart';
import 'package:win32_dart/src/constants.dart';
import 'package:win32_dart/src/security/security_capabilities.dart';
import 'package:win32_dart/src/win32_failure.dart';
import 'package:win32_dart/src/win32_handle.dart';

/// One entry of a `PROC_THREAD_ATTRIBUTE_LIST`.
class ProcThreadAttribute {
  const ProcThreadAttribute._({
    required this.attribute,
    required this.value,
    required this.size,
    required this.ownedValue,
  });

  /// The `PSEUDOCONSOLE` attribute for [console].
  factory ProcThreadAttribute.pseudoConsole(PseudoConsole console) =>
      ProcThreadAttribute._(
        attribute: procThreadAttributePseudoconsole,
        // The HPCON is passed by value in the pointer slot — MS's documented
        // special case, confirmed by the spike — with its own size.
        value: console.handle,
        size: sizeOf<HPCON>(),
        ownedValue: nullptr,
      );

  /// The `HANDLE_LIST` attribute naming exactly [handles], so a child with
  /// `bInheritHandles` inherits those and nothing else. The array is copied
  /// into memory the list owns.
  factory ProcThreadAttribute.handleList(List<Win32Handle> handles) {
    final array = calloc<HANDLE>(handles.length);
    for (var i = 0; i < handles.length; i++) {
      array[i] = handles[i];
    }
    return ProcThreadAttribute._(
      attribute: procThreadAttributeHandleList,
      value: array.cast<Void>(),
      size: handles.length * sizeOf<HANDLE>(),
      ownedValue: array.cast<Void>(),
    );
  }

  /// The `SECURITY_CAPABILITIES` attribute running the child under [caps]'
  /// AppContainer SID. [caps] owns its own memory (struct + capability array)
  /// and must outlive the spawn, so the finished list frees none of it.
  factory ProcThreadAttribute.securityCapabilities(SecurityCapabilities caps) =>
      ProcThreadAttribute._(
        attribute: procThreadAttributeSecurityCapabilities,
        value: caps.pointer.cast<Void>(),
        size: caps.size,
        ownedValue: nullptr,
      );

  /// The `PROC_THREAD_ATTRIBUTE_*` identifier.
  final int attribute;

  /// What `UpdateProcThreadAttribute` is handed in the value slot.
  final Pointer<Void> value;

  /// The value's size in bytes.
  final int size;

  /// Memory the finished list frees, or `nullptr` when it owns none.
  final Pointer<Void> ownedValue;
}

/// Builds the attribute lists `CreateProcessW` is handed.
class AttributeLists {
  /// Calls through the given Win32 bindings.
  const AttributeLists(this._bindings);

  final WindowsBindings _bindings;

  /// Builds a list carrying [attributes], in the order given.
  AttributeListResult build(List<ProcThreadAttribute> attributes) {
    final owned = [
      for (final attribute in attributes)
        if (attribute.ownedValue != nullptr) attribute.ownedValue,
    ];
    void freeOwned() => owned.forEach(calloc.free);

    final sizeOut = calloc<UnsignedLongLong>();
    // The first call is expected to "fail" — it only reports the byte count
    // the list needs — so its return is ignored and the size read back.
    _bindings.InitializeProcThreadAttributeList(
      nullptr,
      attributes.length,
      0,
      sizeOut,
    );
    final list = calloc<Uint8>(
      sizeOut.value,
    ).cast<PROC_THREAD_ATTRIBUTE_LIST>();
    try {
      final initialized = _bindings.InitializeProcThreadAttributeList(
        list,
        attributes.length,
        0,
        sizeOut,
      );
      if (initialized == 0) {
        final failure = Win32Failure.fromLastError(
          _bindings,
          'InitializeProcThreadAttributeList',
        );
        calloc.free(list);
        freeOwned();
        return AttributeListFailed(failure);
      }
      for (var i = 0; i < attributes.length; i++) {
        final attribute = attributes[i];
        if (_bindings.UpdateProcThreadAttribute(
              list,
              0,
              attribute.attribute,
              attribute.value,
              attribute.size,
              nullptr,
              nullptr,
            ) ==
            0) {
          final failure = Win32Failure.fromLastError(
            _bindings,
            'UpdateProcThreadAttribute',
          );
          _bindings.DeleteProcThreadAttributeList(list);
          calloc.free(list);
          freeOwned();
          return AttributeListFailed(failure);
        }
      }
      return AttributeListSucceeded(AttributeList._(_bindings, list, owned));
    } finally {
      calloc.free(sizeOut);
    }
  }
}

/// A `PROC_THREAD_ATTRIBUTE_LIST` handed to `CreateProcessW`, allocated,
/// initialised and deleted exactly once.
class AttributeList {
  AttributeList._(this._bindings, this._list, this._owned);

  final WindowsBindings _bindings;
  final Pointer<PROC_THREAD_ATTRIBUTE_LIST> _list;
  final List<Pointer<Void>> _owned;
  bool _closed = false;

  /// The list pointer, for `STARTUPINFOEXW.lpAttributeList`.
  Pointer<PROC_THREAD_ATTRIBUTE_LIST> get pointer => _list;

  /// Deletes the list and frees its backing memory. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    _bindings.DeleteProcThreadAttributeList(_list);
    calloc.free(_list);
    _owned.forEach(calloc.free);
  }
}

sealed class AttributeListResult {
  const AttributeListResult();
}

final class AttributeListSucceeded extends AttributeListResult {
  const AttributeListSucceeded(this.attributeList);
  final AttributeList attributeList;
}

final class AttributeListFailed extends AttributeListResult {
  const AttributeListFailed(this.failure);
  final Win32Failure failure;
}
