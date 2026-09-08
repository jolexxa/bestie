import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/security/sid.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// A provisioned AppContainer profile: its name, and the package SID a confined
/// process runs as. The profile is machine-persistent (survives process exit),
/// so its lifecycle — provision, reuse, delete — is the caller's to own.
class AppContainerProfile {
  AppContainerProfile._(this._bindings, this.name, this.sid);

  final WindowsBindings _bindings;

  /// The profile name it was provisioned under, e.g.
  /// `bestie.sandbox.<workspace-hash>`.
  final String name;

  /// The package SID a child is confined to via `SECURITY_CAPABILITIES`.
  final Sid sid;

  bool _closed = false;

  /// The folder Windows created for this profile under
  /// `%LOCALAPPDATA%\Packages`, which the package SID can already write —
  /// where a confined child's own temp directory lives.
  AppContainerFolderResult folder() {
    final sidString = sid.asString();
    if (sidString == null) {
      return const AppContainerFolderFailed(
        Win32Failure.withoutCode(
          'GetAppContainerFolderPath',
          'container SID is unprintable',
        ),
      );
    }
    final sidPtr = sidString.toNativeUtf16(allocator: calloc).cast<WChar>();
    final pathOut = calloc<Pointer<WChar>>();
    try {
      final hr = _bindings.GetAppContainerFolderPath(sidPtr, pathOut);
      if (hr != 0) {
        return AppContainerFolderFailed(
          Win32Failure.withoutCode(
            'GetAppContainerFolderPath',
            'HRESULT 0x${hr.toUnsigned(32).toRadixString(16)}',
          ),
        );
      }
      final path = pathOut.value.cast<Utf16>().toDartString();
      _bindings.CoTaskMemFree(pathOut.value.cast());
      return AppContainerFolderSucceeded(path);
    } finally {
      calloc
        ..free(sidPtr)
        ..free(pathOut);
    }
  }

  /// Removes the machine-persistent profile. Best paired with [close] on
  /// teardown. Returns the failure, or null on success (including "already
  /// gone", which Windows reports as a benign error).
  Win32Failure? delete() {
    final name = this.name.toNativeUtf16(allocator: calloc).cast<WChar>();
    try {
      final hr = _bindings.DeleteAppContainerProfile(name);
      if (hr == 0) return null;
      return Win32Failure.withoutCode(
        'DeleteAppContainerProfile',
        'HRESULT 0x${hr.toUnsigned(32).toRadixString(16)}',
      );
    } finally {
      calloc.free(name);
    }
  }

  /// Frees the SID. Does NOT delete the persistent profile — call [delete]
  /// first if teardown needs it gone. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    sid.close();
  }
}

/// Provisions AppContainer profiles.
class AppContainerProfiles {
  /// Calls through the given Win32 bindings.
  AppContainerProfiles(this._bindings) : _sids = Sids(_bindings);

  final WindowsBindings _bindings;
  final Sids _sids;

  /// Provisions the profile [name], or derives its SID when it already exists
  /// (the reconciliation hook — a workspace reopened in a later session reuses
  /// the same profile). [displayName] and [description] are shown in Windows'
  /// own UI; the OS requires both.
  AppContainerProfileResult provision({
    required String name,
    required String displayName,
    String? description,
  }) {
    final namePtr = name.toNativeUtf16(allocator: calloc).cast<WChar>();
    final displayPtr = displayName
        .toNativeUtf16(allocator: calloc)
        .cast<WChar>();
    final descriptionPtr = (description ?? displayName)
        .toNativeUtf16(allocator: calloc)
        .cast<WChar>();
    final sidOut = calloc<Pointer<Void>>();
    final derivedOut = calloc<Pointer<Void>>();
    try {
      final created = _bindings.CreateAppContainerProfile(
        namePtr,
        displayPtr,
        descriptionPtr,
        nullptr,
        0,
        sidOut,
      );
      if (created == 0) {
        return AppContainerProfileSucceeded(
          AppContainerProfile._(
            _bindings,
            name,
            _sids.adoptAppContainerSid(sidOut.value),
          ),
        );
      }

      final derived = _bindings.DeriveAppContainerSidFromAppContainerName(
        namePtr,
        derivedOut,
      );
      if (derived != 0) {
        return AppContainerProfileFailed(
          Win32Failure.withoutCode(
            'CreateAppContainerProfile',
            'create=0x${created.toUnsigned(32).toRadixString(16)} '
                'derive=0x${derived.toUnsigned(32).toRadixString(16)}',
          ),
        );
      }
      return AppContainerProfileSucceeded(
        AppContainerProfile._(
          _bindings,
          name,
          _sids.adoptAppContainerSid(derivedOut.value),
        ),
      );
    } finally {
      calloc
        ..free(namePtr)
        ..free(displayPtr)
        ..free(descriptionPtr)
        ..free(sidOut)
        ..free(derivedOut);
    }
  }
}

sealed class AppContainerProfileResult {
  const AppContainerProfileResult();
}

final class AppContainerProfileSucceeded extends AppContainerProfileResult {
  const AppContainerProfileSucceeded(this.profile);
  final AppContainerProfile profile;
}

final class AppContainerProfileFailed extends AppContainerProfileResult {
  const AppContainerProfileFailed(this.failure);
  final Win32Failure failure;
}

/// Whether a profile's folder could be resolved.
sealed class AppContainerFolderResult {
  const AppContainerFolderResult();
}

/// Resolved; the profile's folder is [path].
final class AppContainerFolderSucceeded extends AppContainerFolderResult {
  /// Wraps the folder [path].
  const AppContainerFolderSucceeded(this.path);

  /// The absolute folder path.
  final String path;
}

/// Windows could not report the folder, for [failure].
final class AppContainerFolderFailed extends AppContainerFolderResult {
  /// Wraps the [failure].
  const AppContainerFolderFailed(this.failure);

  /// Why the folder could not be resolved.
  final Win32Failure failure;
}
