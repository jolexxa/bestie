import 'package:sandbox_windows/src/windows_provisioner.dart';
import 'package:win32_dart/win32_dart.dart';

/// The real [WindowsProvisioner], over win32_dart. Owns each provisioned
/// profile (and its SID) keyed by SID string, so the adapter can drive grants,
/// holes, and teardown through opaque strings while the native handles live and
/// die here.
class Win32Provisioner implements WindowsProvisioner {
  /// Calls through [bindings] (the real host by default).
  Win32Provisioner({WindowsBindings? bindings}) : _bindings = bindings ?? win32;

  final WindowsBindings _bindings;
  final Map<String, AppContainerProfile> _profiles = {};

  @override
  ProvisionOutcome provision(String name) {
    final result = AppContainerProfiles(
      _bindings,
    ).provision(name: name, displayName: 'bestie sandbox');
    switch (result) {
      case AppContainerProfileSucceeded(:final profile):
        final sid = profile.sid.asString();
        if (sid == null) {
          profile.close();
          return const ProvisionFailed('container SID is unprintable');
        }
        switch (profile.folder()) {
          case AppContainerFolderSucceeded(:final path):
            // A profile already live under this SID keeps its handle.
            if (_profiles.containsKey(sid)) {
              profile.close();
            } else {
              _profiles[sid] = profile;
            }
            return ProvisionSucceeded(sid, folder: path);
          case AppContainerFolderFailed(:final failure):
            profile.close();
            return ProvisionFailed(failure.toString());
        }
      case AppContainerProfileFailed(:final failure):
        return ProvisionFailed(failure.toString());
    }
  }

  @override
  String? grant({
    required String containerSid,
    required String path,
    required bool write,
  }) {
    final profile = _profiles[containerSid];
    if (profile == null) return 'no live profile for $containerSid';
    final result = Dacls(_bindings).grant(
      path: path,
      trustee: profile.sid,
      rights: write ? fileAllAccess : fileReadExecuteRights,
    );
    return result is DaclFailed ? result.failure.toString() : null;
  }

  @override
  GrantInspection holds({
    required String containerSid,
    required String path,
    required bool write,
  }) {
    final profile = _profiles[containerSid];
    if (profile == null) {
      return GrantInspectionFailed('no live profile for $containerSid');
    }
    return _inspection(
      Dacls(_bindings).holds(
        path: path,
        trustee: profile.sid,
        rights: write ? fileAllAccess : fileReadExecuteRights,
      ),
    );
  }

  @override
  String? grantCapability({
    required String capabilitySid,
    required String path,
    int inheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT,
  }) {
    final parsed = Sids(_bindings).fromString(capabilitySid);
    if (parsed is! SidSucceeded) {
      return 'unparseable capability SID $capabilitySid';
    }
    try {
      final result = Dacls(_bindings).grant(
        path: path,
        trustee: parsed.sid,
        rights: fileReadExecuteRights,
        inheritance: inheritance,
      );
      return result is DaclFailed ? result.failure.toString() : null;
    } finally {
      parsed.sid.close();
    }
  }

  @override
  GrantInspection holdsCapability({
    required String capabilitySid,
    required String path,
    int inheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT,
  }) {
    final parsed = Sids(_bindings).fromString(capabilitySid);
    if (parsed is! SidSucceeded) {
      return GrantInspectionFailed('unparseable capability SID $capabilitySid');
    }
    try {
      return _inspection(
        Dacls(_bindings).holds(
          path: path,
          trustee: parsed.sid,
          rights: fileReadExecuteRights,
          inheritance: inheritance,
        ),
      );
    } finally {
      parsed.sid.close();
    }
  }

  GrantInspection _inspection(DaclInspection inspection) =>
      switch (inspection) {
        DaclHeld() => const GrantHeld(),
        DaclMissing() => const GrantMissing(),
        DaclInspectionFailed(:final failure) => GrantInspectionFailed(
          failure.toString(),
        ),
      };

  @override
  void revokeCapability({
    required String capabilitySid,
    required String path,
  }) {
    final parsed = Sids(_bindings).fromString(capabilitySid);
    if (parsed is! SidSucceeded) return;
    try {
      Dacls(_bindings).revoke(path: path, trustee: parsed.sid);
    } finally {
      parsed.sid.close();
    }
  }

  @override
  String? protect(String path) {
    final result = Dacls(_bindings).protect(path);
    return result is DaclFailed ? result.failure.toString() : null;
  }

  @override
  void revoke({required String containerSid, required String path}) {
    final profile = _profiles[containerSid];
    if (profile == null) return;
    Dacls(_bindings).revoke(path: path, trustee: profile.sid);
  }

  @override
  void unprotect(String path) => Dacls(_bindings).unprotect(path);

  @override
  LoopbackOutcome addLoopback(String containerSid) {
    final exemptions = LoopbackExemptions(_bindings);
    final listed = exemptions.list();
    final current = listed is LoopbackExemptionListed
        ? listed.containerSids
        : const <String>[];
    return switch (exemptions.replaceAll({...current, containerSid}.toList())) {
      LoopbackExemptionSet() => const LoopbackApplied(),
      LoopbackExemptionDenied() => const LoopbackDeveloperModeOff(),
      LoopbackExemptionSetFailed(:final failure) => LoopbackFailed(
        failure.toString(),
      ),
    };
  }

  @override
  void removeLoopback(String containerSid) {
    final exemptions = LoopbackExemptions(_bindings);
    final listed = exemptions.list();
    if (listed is! LoopbackExemptionListed) return;
    exemptions.replaceAll(
      listed.containerSids.where((sid) => sid != containerSid).toList(),
    );
  }

  @override
  void dispose(String containerSid) {
    final profile = _profiles.remove(containerSid);
    if (profile == null) return;
    profile
      ..delete()
      ..close();
  }
}
