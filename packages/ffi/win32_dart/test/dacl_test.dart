import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

const _path = r'C:\Users\cow\project';
const _trusteeSid = 'S-1-15-2-1';
const _otherSid = 'S-1-15-2-2';

/// The addresses the fake SID parser hands out, so the ACE walk can tell the
/// trustee from a stranger by pointer identity alone.
final _trusteePointer = Pointer<Void>.fromAddress(0x51D);
final _otherPointer = Pointer<Void>.fromAddress(0x0DD);
final _daclPointer = Pointer<ACL>.fromAddress(0xAC1);

void main() {
  late MockWindowsBindings bindings;
  late Sid trustee;
  final freed = <Pointer<Void>>[];
  final allocated = <Pointer<Void>>[];

  setUpAll(registerPointerFallbacks);

  Pointer<WChar> allocateWide(String value) {
    final buffer = calloc<WChar>(value.length + 1);
    writeWide(buffer, value);
    allocated.add(buffer.cast());
    return buffer;
  }

  setUp(() {
    bindings = MockWindowsBindings();
    freed.clear();
    allocated.clear();
    when(() => bindings.ConvertStringSidToSidW(any(), any())).thenAnswer((
      invocation,
    ) {
      (invocation.positionalArguments[1] as Pointer<Pointer<Void>>).value =
          _trusteePointer;
      return 1;
    });
    when(() => bindings.ConvertSidToStringSidW(any(), any())).thenAnswer((
      invocation,
    ) {
      final sid = invocation.positionalArguments[0] as Pointer<Void>;
      (invocation.positionalArguments[1] as Pointer<Pointer<WChar>>).value =
          allocateWide(sid == _trusteePointer ? _trusteeSid : _otherSid);
      return 1;
    });
    when(() => bindings.LocalFree(any())).thenAnswer((invocation) {
      final pointer = invocation.positionalArguments[0] as Pointer<Void>;
      freed.add(pointer);
      if (allocated.remove(pointer)) calloc.free(pointer);
      return nullptr;
    });
    whenFormatMessage(bindings, 'nope');
    trustee = (Sids(bindings).fromString(_trusteeSid) as SidSucceeded).sid;
  });

  /// Stubs the DACL read to succeed, handing back a descriptor to free.
  void whenDaclReads() {
    when(
      () => bindings.GetNamedSecurityInfoW(
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenAnswer((invocation) {
      (invocation.positionalArguments[5] as Pointer<Pointer<ACL>>).value =
          _daclPointer;
      final descriptor = calloc<Uint8>().cast<Void>();
      allocated.add(descriptor);
      (invocation.positionalArguments[7] as Pointer<Pointer<Void>>).value =
          descriptor;
      return 0;
    });
  }

  /// Stubs the explicit-entry listing with [entries], each described as
  /// (mode, rights, inheritance, trustee pointer).
  void whenEntriesAre(List<(ACCESS_MODE, int, int, Pointer<Void>)> entries) {
    when(
      () => bindings.GetExplicitEntriesFromAclW(any(), any(), any()),
    ).thenAnswer((invocation) {
      final list = calloc<EXPLICIT_ACCESS_W>(entries.length);
      allocated.add(list.cast());
      for (var i = 0; i < entries.length; i++) {
        final (mode, rights, inheritance, sid) = entries[i];
        list[i]
          ..grfAccessModeAsInt = mode.value
          ..grfAccessPermissions = rights
          ..grfInheritance = inheritance;
        list[i].Trustee.ptstrName = sid.cast();
      }
      (invocation.positionalArguments[1] as Pointer<UnsignedLong>).value =
          entries.length;
      (invocation.positionalArguments[2] as Pointer<Pointer<EXPLICIT_ACCESS_W>>)
              .value =
          list;
      return 0;
    });
  }

  DaclInspection inspect({
    int inheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT,
  }) => Dacls(bindings).holds(
    path: _path,
    trustee: trustee,
    rights: fileAllAccess,
    inheritance: inheritance,
  );

  group('holds', () {
    test(
      'is held by an explicit grant covering the rights and inheritance',
      () {
        whenDaclReads();
        whenEntriesAre([
          (
            ACCESS_MODE.GRANT_ACCESS,
            fileAllAccess,
            SUB_CONTAINERS_AND_OBJECTS_INHERIT,
            _trusteePointer,
          ),
        ]);

        expect(inspect(), isA<DaclHeld>());
        expect(allocated, isEmpty, reason: 'descriptor and entries are freed');
      },
    );

    test('is held by a grant broader than what was asked', () {
      whenDaclReads();
      whenEntriesAre([
        (
          ACCESS_MODE.GRANT_ACCESS,
          fileAllAccess,
          SUB_CONTAINERS_AND_OBJECTS_INHERIT,
          _trusteePointer,
        ),
      ]);

      expect(inspect(inheritance: NO_INHERITANCE), isA<DaclHeld>());
    });

    test(
      'is held by the specific rights Windows stores a generic grant as',
      () {
        whenDaclReads();
        whenEntriesAre([
          (
            ACCESS_MODE.GRANT_ACCESS,
            fileGenericRead | fileGenericExecute,
            NO_INHERITANCE,
            _trusteePointer,
          ),
        ]);

        final inspection = Dacls(bindings).holds(
          path: _path,
          trustee: trustee,
          rights: fileReadExecuteRights,
          inheritance: NO_INHERITANCE,
        );

        expect(inspection, isA<DaclHeld>());
      },
    );

    test('is missing when the stored rights fall short of the generic ask', () {
      whenDaclReads();
      whenEntriesAre([
        (
          ACCESS_MODE.GRANT_ACCESS,
          fileGenericRead,
          NO_INHERITANCE,
          _trusteePointer,
        ),
      ]);

      final inspection = Dacls(bindings).holds(
        path: _path,
        trustee: trustee,
        rights: fileReadExecuteRights,
        inheritance: NO_INHERITANCE,
      );

      expect(inspection, isA<DaclMissing>());
    });

    test('is missing when the DACL has no entries at all', () {
      whenDaclReads();
      whenEntriesAre([]);

      expect(inspect(), isA<DaclMissing>());
    });

    test('ignores an entry that only flowed down from a parent', () {
      whenDaclReads();
      whenEntriesAre([
        (
          ACCESS_MODE.GRANT_ACCESS,
          fileAllAccess,
          SUB_CONTAINERS_AND_OBJECTS_INHERIT | INHERITED_ACE,
          _trusteePointer,
        ),
      ]);

      expect(inspect(), isA<DaclMissing>());
    });

    test("ignores a deny, a narrower grant, and a stranger's grant", () {
      whenDaclReads();
      whenEntriesAre([
        (
          ACCESS_MODE.DENY_ACCESS,
          fileAllAccess,
          SUB_CONTAINERS_AND_OBJECTS_INHERIT,
          _trusteePointer,
        ),
        (
          ACCESS_MODE.GRANT_ACCESS,
          fileReadExecuteRights,
          SUB_CONTAINERS_AND_OBJECTS_INHERIT,
          _trusteePointer,
        ),
        (
          ACCESS_MODE.GRANT_ACCESS,
          fileAllAccess,
          NO_INHERITANCE,
          _trusteePointer,
        ),
        (
          ACCESS_MODE.GRANT_ACCESS,
          fileAllAccess,
          SUB_CONTAINERS_AND_OBJECTS_INHERIT,
          _otherPointer,
        ),
      ]);

      expect(inspect(), isA<DaclMissing>());
    });

    test('is missing without reading when the trustee is unprintable', () {
      when(() => bindings.ConvertSidToStringSidW(any(), any())).thenReturn(0);

      expect(inspect(), isA<DaclMissing>());
      verifyNever(
        () => bindings.GetNamedSecurityInfoW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      );
    });

    test('fails when the DACL cannot be read', () {
      when(
        () => bindings.GetNamedSecurityInfoW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(5);

      final result = inspect();

      expect(result, isA<DaclInspectionFailed>());
      expect(
        (result as DaclInspectionFailed).failure.function,
        'GetNamedSecurityInfoW',
      );
    });

    test('fails when the entries cannot be listed', () {
      whenDaclReads();
      when(
        () => bindings.GetExplicitEntriesFromAclW(any(), any(), any()),
      ).thenReturn(8);

      final result = inspect();

      expect(result, isA<DaclInspectionFailed>());
      expect(
        (result as DaclInspectionFailed).failure.function,
        'GetExplicitEntriesFromAclW',
      );
      expect(allocated, isEmpty, reason: 'the descriptor is still freed');
    });
  });

  group('grant and revoke', () {
    final newDacl = Pointer<ACL>.fromAddress(0xAC2);

    // The entry handed to SetEntriesInAclW, copied out while its memory is
    // still alive — the call frees it before returning.
    late Map<String, int> asked;

    void whenAclBuilds() {
      when(
        () => bindings.SetEntriesInAclW(any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        final entry =
            (invocation.positionalArguments[1] as Pointer<EXPLICIT_ACCESS_W>)
                .ref;
        asked = {
          'count': invocation.positionalArguments[0] as int,
          'mode': entry.grfAccessModeAsInt,
          'rights': entry.grfAccessPermissions,
          'inheritance': entry.grfInheritance,
        };
        (invocation.positionalArguments[3] as Pointer<Pointer<ACL>>).value =
            newDacl;
        return 0;
      });
    }

    void whenAclWrites(int code) {
      when(
        () => bindings.SetNamedSecurityInfoW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(code);
    }

    test('grant merges one inheritable allow ACE for the trustee', () {
      whenDaclReads();
      whenAclBuilds();
      whenAclWrites(0);

      final result = Dacls(bindings).grant(
        path: _path,
        trustee: trustee,
        rights: fileAllAccess,
      );

      expect(result, isA<DaclSucceeded>());
      verify(
        () => bindings.SetEntriesInAclW(1, any(), _daclPointer, any()),
      ).called(1);
      expect(asked['mode'], ACCESS_MODE.GRANT_ACCESS.value);
      expect(asked['rights'], fileAllAccess);
      expect(asked['inheritance'], SUB_CONTAINERS_AND_OBJECTS_INHERIT);
      verify(
        () => bindings.SetNamedSecurityInfoW(
          any(),
          any(),
          DACL_SECURITY_INFORMATION,
          any(),
          any(),
          newDacl,
          any(),
        ),
      ).called(1);
      expect(freed, contains(newDacl.cast<Void>()));
    });

    test('revoke merges a revoke ACE with no rights', () {
      whenDaclReads();
      whenAclBuilds();
      whenAclWrites(0);

      final result = Dacls(bindings).revoke(path: _path, trustee: trustee);

      expect(result, isA<DaclSucceeded>());
      expect(asked['count'], 1);
      expect(asked['mode'], ACCESS_MODE.REVOKE_ACCESS.value);
      expect(asked['rights'], 0);
    });

    test('fails when the DACL cannot be read', () {
      when(
        () => bindings.GetNamedSecurityInfoW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(5);

      final result = Dacls(bindings).grant(
        path: _path,
        trustee: trustee,
        rights: fileAllAccess,
      );

      expect(result, isA<DaclFailed>());
      expect((result as DaclFailed).failure.function, 'GetNamedSecurityInfoW');
    });

    test('fails when the merged ACL cannot be built', () {
      whenDaclReads();
      when(
        () => bindings.SetEntriesInAclW(any(), any(), any(), any()),
      ).thenReturn(87);

      final result = Dacls(bindings).grant(
        path: _path,
        trustee: trustee,
        rights: fileAllAccess,
      );

      expect(result, isA<DaclFailed>());
      expect((result as DaclFailed).failure.function, 'SetEntriesInAclW');
    });

    test('fails when the merged ACL cannot be written', () {
      whenDaclReads();
      whenAclBuilds();
      whenAclWrites(5);

      final result = Dacls(bindings).grant(
        path: _path,
        trustee: trustee,
        rights: fileAllAccess,
      );

      expect(result, isA<DaclFailed>());
      expect((result as DaclFailed).failure.function, 'SetNamedSecurityInfoW');
      expect(freed, contains(newDacl.cast<Void>()));
    });
  });

  group('protect and unprotect', () {
    final empty = Pointer<ACL>.fromAddress(0xAC3);

    void whenEmptyAclBuilds() {
      when(
        () => bindings.SetEntriesInAclW(0, any(), any(), any()),
      ).thenAnswer((invocation) {
        (invocation.positionalArguments[3] as Pointer<Pointer<ACL>>).value =
            empty;
        return 0;
      });
    }

    test('protect writes an empty DACL that stops inheriting', () {
      whenEmptyAclBuilds();
      when(
        () => bindings.SetNamedSecurityInfoW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(0);

      expect(Dacls(bindings).protect(_path), isA<DaclSucceeded>());
      verify(
        () => bindings.SetNamedSecurityInfoW(
          any(),
          any(),
          DACL_SECURITY_INFORMATION | protectedDaclSecurityInformation,
          any(),
          any(),
          empty,
          any(),
        ),
      ).called(1);
      expect(freed, contains(empty.cast<Void>()));
    });

    test('unprotect writes an empty DACL that inherits again', () {
      whenEmptyAclBuilds();
      when(
        () => bindings.SetNamedSecurityInfoW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(0);

      expect(Dacls(bindings).unprotect(_path), isA<DaclSucceeded>());
      verify(
        () => bindings.SetNamedSecurityInfoW(
          any(),
          any(),
          DACL_SECURITY_INFORMATION | unprotectedDaclSecurityInformation,
          any(),
          any(),
          empty,
          any(),
        ),
      ).called(1);
    });

    test('fails when the empty ACL cannot be built', () {
      when(
        () => bindings.SetEntriesInAclW(any(), any(), any(), any()),
      ).thenReturn(87);

      final result = Dacls(bindings).protect(_path);

      expect(result, isA<DaclFailed>());
      expect((result as DaclFailed).failure.function, 'SetEntriesInAclW');
    });

    test('fails when the empty DACL cannot be written', () {
      whenEmptyAclBuilds();
      when(
        () => bindings.SetNamedSecurityInfoW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(5);

      final result = Dacls(bindings).protect(_path);

      expect(result, isA<DaclFailed>());
      expect((result as DaclFailed).failure.function, 'SetNamedSecurityInfoW');
    });
  });
}
