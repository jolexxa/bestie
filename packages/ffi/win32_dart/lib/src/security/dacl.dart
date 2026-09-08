import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/constants.dart';
import 'package:win32_dart/src/security/sid.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// Applies discretionary ACL changes to filesystem objects — the grants that
/// let a confined AppContainer reach a path, the revokes that undo them, and
/// the broken-inheritance "hole" that carves a denied subpath out of a granted
/// root (deny ACEs are not honoured for a package SID — see sandbox).
///
/// Grants and revokes MERGE into the object's existing DACL; the hole
/// operations REPLACE it, so a granted root's own ACEs are left untouched.
class Dacls {
  /// Calls through the given Win32 bindings.
  const Dacls(this._bindings);

  final WindowsBindings _bindings;

  /// Grants [trustee] [rights] on [path], propagating by [inheritance]
  /// (default: to sub-containers and objects, so descendants inherit it).
  DaclResult grant({
    required String path,
    required Sid trustee,
    required int rights,
    int inheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT,
  }) => _merge(path, trustee, ACCESS_MODE.GRANT_ACCESS, rights, inheritance);

  /// Removes every ACE naming [trustee] from [path]'s DACL — the teardown of a
  /// [grant].
  DaclResult revoke({required String path, required Sid trustee}) =>
      _merge(path, trustee, ACCESS_MODE.REVOKE_ACCESS, 0, NO_INHERITANCE);

  /// Severs [path] from inherited ACEs and empties its DACL, so a container
  /// granted on an ancestor reaches everything under it except this hole.
  DaclResult protect(String path) => _replaceEmpty(
    path,
    DACL_SECURITY_INFORMATION | protectedDaclSecurityInformation,
  );

  /// Restores inheritance on [path], undoing [protect] so the hole re-inherits
  /// its ancestor's grants on teardown.
  DaclResult unprotect(String path) => _replaceEmpty(
    path,
    DACL_SECURITY_INFORMATION | unprotectedDaclSecurityInformation,
  );

  /// Whether [path]'s own (non-inherited) DACL grants [trustee] at least
  /// [rights] with at least [inheritance].
  DaclInspection holds({
    required String path,
    required Sid trustee,
    required int rights,
    int inheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT,
  }) {
    final wanted = trustee.asString();
    if (wanted == null) return const DaclMissing();
    final wantedRights = fileSpecificRights(rights);
    final name = path.toNativeUtf16(allocator: calloc).cast<WChar>();
    final dacl = calloc<Pointer<ACL>>();
    final descriptor = calloc<Pointer<Void>>();
    final count = calloc<UnsignedLong>();
    final entries = calloc<Pointer<EXPLICIT_ACCESS_W>>();
    try {
      final read = _bindings.GetNamedSecurityInfoW(
        name,
        SE_OBJECT_TYPE.SE_FILE_OBJECT,
        DACL_SECURITY_INFORMATION,
        nullptr,
        nullptr,
        dacl,
        nullptr,
        descriptor,
      );
      if (read != 0) {
        return DaclInspectionFailed(
          Win32Failure.fromCode(_bindings, 'GetNamedSecurityInfoW', read),
        );
      }
      final listed = _bindings.GetExplicitEntriesFromAclW(
        dacl.value,
        count,
        entries,
      );
      if (listed != 0) {
        return DaclInspectionFailed(
          Win32Failure.fromCode(
            _bindings,
            'GetExplicitEntriesFromAclW',
            listed,
          ),
        );
      }
      final sids = Sids(_bindings);
      for (var i = 0; i < count.value; i++) {
        final entry = entries.value[i];
        if (entry.grfAccessModeAsInt != ACCESS_MODE.GRANT_ACCESS.value) {
          continue;
        }
        if (entry.grfInheritance & INHERITED_ACE != 0) continue;
        final held = fileSpecificRights(entry.grfAccessPermissions);
        if (held & wantedRights != wantedRights) continue;
        if (entry.grfInheritance & inheritance != inheritance) continue;
        if (sids.stringOf(entry.Trustee.ptstrName.cast()) != wanted) continue;
        return const DaclHeld();
      }
      return const DaclMissing();
    } finally {
      if (entries.value != nullptr) _bindings.LocalFree(entries.value.cast());
      if (descriptor.value != nullptr) _bindings.LocalFree(descriptor.value);
      calloc
        ..free(name)
        ..free(dacl)
        ..free(descriptor)
        ..free(count)
        ..free(entries);
    }
  }

  DaclResult _merge(
    String path,
    Sid trustee,
    ACCESS_MODE mode,
    int rights,
    int inheritance,
  ) {
    final name = path.toNativeUtf16(allocator: calloc).cast<WChar>();
    final oldDacl = calloc<Pointer<ACL>>();
    final descriptor = calloc<Pointer<Void>>();
    final entries = calloc<EXPLICIT_ACCESS_W>();
    final newDacl = calloc<Pointer<ACL>>();
    try {
      final read = _bindings.GetNamedSecurityInfoW(
        name,
        SE_OBJECT_TYPE.SE_FILE_OBJECT,
        DACL_SECURITY_INFORMATION,
        nullptr,
        nullptr,
        oldDacl,
        nullptr,
        descriptor,
      );
      if (read != 0) {
        return DaclFailed(
          Win32Failure.fromCode(_bindings, 'GetNamedSecurityInfoW', read),
        );
      }

      entries.ref
        ..grfAccessPermissions = rights
        ..grfAccessModeAsInt = mode.value
        ..grfInheritance = inheritance;
      entries.ref.Trustee
        ..pMultipleTrustee = nullptr
        ..MultipleTrusteeOperationAsInt =
            MULTIPLE_TRUSTEE_OPERATION.NO_MULTIPLE_TRUSTEE.value
        ..TrusteeFormAsInt = TRUSTEE_FORM.TRUSTEE_IS_SID.value
        ..TrusteeTypeAsInt = TRUSTEE_TYPE.TRUSTEE_IS_GROUP.value
        ..ptstrName = trustee.pointer.cast<WChar>();

      final built = _bindings.SetEntriesInAclW(
        1,
        entries,
        oldDacl.value,
        newDacl,
      );
      if (built != 0) {
        return DaclFailed(
          Win32Failure.fromCode(_bindings, 'SetEntriesInAclW', built),
        );
      }

      final wrote = _bindings.SetNamedSecurityInfoW(
        name,
        SE_OBJECT_TYPE.SE_FILE_OBJECT,
        DACL_SECURITY_INFORMATION,
        nullptr,
        nullptr,
        newDacl.value,
        nullptr,
      );
      if (wrote != 0) {
        return DaclFailed(
          Win32Failure.fromCode(_bindings, 'SetNamedSecurityInfoW', wrote),
        );
      }
      return const DaclSucceeded();
    } finally {
      if (descriptor.value != nullptr) _bindings.LocalFree(descriptor.value);
      if (newDacl.value != nullptr) _bindings.LocalFree(newDacl.value.cast());
      calloc
        ..free(name)
        ..free(oldDacl)
        ..free(descriptor)
        ..free(entries)
        ..free(newDacl);
    }
  }

  DaclResult _replaceEmpty(String path, int securityInfo) {
    final name = path.toNativeUtf16(allocator: calloc).cast<WChar>();
    final empty = calloc<Pointer<ACL>>();
    try {
      final made = _bindings.SetEntriesInAclW(0, nullptr, nullptr, empty);
      if (made != 0) {
        return DaclFailed(
          Win32Failure.fromCode(_bindings, 'SetEntriesInAclW', made),
        );
      }
      final wrote = _bindings.SetNamedSecurityInfoW(
        name,
        SE_OBJECT_TYPE.SE_FILE_OBJECT,
        securityInfo,
        nullptr,
        nullptr,
        empty.value,
        nullptr,
      );
      if (wrote != 0) {
        return DaclFailed(
          Win32Failure.fromCode(_bindings, 'SetNamedSecurityInfoW', wrote),
        );
      }
      return const DaclSucceeded();
    } finally {
      if (empty.value != nullptr) _bindings.LocalFree(empty.value.cast());
      calloc
        ..free(name)
        ..free(empty);
    }
  }
}

sealed class DaclResult {
  const DaclResult();
}

final class DaclSucceeded extends DaclResult {
  const DaclSucceeded();
}

final class DaclFailed extends DaclResult {
  const DaclFailed(this.failure);
  final Win32Failure failure;
}

/// What an inspection found on the object's own DACL.
sealed class DaclInspection {
  const DaclInspection();
}

/// An explicit ACE grants the trustee what was asked.
final class DaclHeld extends DaclInspection {
  const DaclHeld();
}

/// No explicit ACE grants it.
final class DaclMissing extends DaclInspection {
  const DaclMissing();
}

/// The DACL could not be read.
final class DaclInspectionFailed extends DaclInspection {
  const DaclInspectionFailed(this.failure);
  final Win32Failure failure;
}
