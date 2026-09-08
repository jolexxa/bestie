import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

const _sid = 'S-1-15-2-1';
const _folder = r'C:\Users\cow\AppData\Local\Packages\bestie';

void main() {
  late MockWindowsBindings bindings;
  final freed = <Pointer<Void>>[];

  setUpAll(registerPointerFallbacks);

  /// Hands out a heap-allocated UTF-16 copy of [value] through an out-pointer,
  /// the way Windows returns strings it expects the caller to free.
  Pointer<WChar> allocateWide(String value) {
    final buffer = calloc<WChar>(value.length + 1);
    writeWide(buffer, value);
    return buffer;
  }

  setUp(() {
    bindings = MockWindowsBindings();
    freed.clear();
    when(
      () => bindings.CreateAppContainerProfile(
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenAnswer((invocation) {
      (invocation.positionalArguments[5] as Pointer<Pointer<Void>>).value =
          Pointer<Void>.fromAddress(0x51D);
      return 0;
    });
    when(() => bindings.ConvertSidToStringSidW(any(), any())).thenAnswer((
      invocation,
    ) {
      (invocation.positionalArguments[1] as Pointer<Pointer<WChar>>).value =
          allocateWide(_sid);
      return 1;
    });
    when(() => bindings.LocalFree(any())).thenAnswer((invocation) {
      calloc.free(invocation.positionalArguments[0] as Pointer<Void>);
      return nullptr;
    });
    when(() => bindings.FreeSid(any())).thenReturn(nullptr);
    when(() => bindings.CoTaskMemFree(any())).thenAnswer((invocation) {
      final pointer = invocation.positionalArguments[0] as Pointer<Void>;
      freed.add(pointer);
      calloc.free(pointer);
    });
  });

  AppContainerProfile provisioned() =>
      (AppContainerProfiles(bindings).provision(
                name: 'bestie.sandbox.test',
                displayName: 'bestie sandbox',
              )
              as AppContainerProfileSucceeded)
          .profile;

  group('the profile folder', () {
    test('is what Windows reports for the container SID, then freed', () {
      when(() => bindings.GetAppContainerFolderPath(any(), any())).thenAnswer((
        invocation,
      ) {
        final sid = (invocation.positionalArguments[0] as Pointer<WChar>)
            .cast<Utf16>()
            .toDartString();
        expect(sid, _sid);
        (invocation.positionalArguments[1] as Pointer<Pointer<WChar>>).value =
            allocateWide(_folder);
        return 0;
      });

      final result = provisioned().folder();

      expect(result, isA<AppContainerFolderSucceeded>());
      expect((result as AppContainerFolderSucceeded).path, _folder);
      expect(freed, hasLength(1), reason: 'the COM string must be freed');
    });

    test('fails with the HRESULT when Windows cannot report it', () {
      when(
        () => bindings.GetAppContainerFolderPath(any(), any()),
      ).thenReturn(0x80070002);

      final result = provisioned().folder();

      expect(result, isA<AppContainerFolderFailed>());
      final failure = (result as AppContainerFolderFailed).failure;
      expect(failure.function, 'GetAppContainerFolderPath');
      expect(failure.message, contains('0x80070002'));
      expect(freed, isEmpty);
    });

    test('fails without asking Windows when the SID is unprintable', () {
      when(() => bindings.ConvertSidToStringSidW(any(), any())).thenReturn(0);

      final result = provisioned().folder();

      expect(result, isA<AppContainerFolderFailed>());
      verifyNever(() => bindings.GetAppContainerFolderPath(any(), any()));
    });
  });
}
