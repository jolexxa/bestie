import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/text.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

void main() {
  setUpAll(registerPointerFallbacks);

  group('MemoryQuery', () {
    late MockWindowsBindings bindings;

    setUp(() {
      bindings = MockWindowsBindings();
      when(() => bindings.GetLastError()).thenReturn(8);
      whenFormatMessage(bindings, 'Not enough memory.');
    });

    test('reports the physical memory totals', () {
      when(() => bindings.GlobalMemoryStatusEx(any())).thenAnswer((invocation) {
        final status =
            (invocation.positionalArguments[0] as Pointer<MEMORYSTATUSEX>).ref
              ..ullTotalPhys = 66158080000
              ..ullAvailPhys = 47353069568;
        expect(status.dwLength, sizeOf<MEMORYSTATUSEX>());
        return 1;
      });

      final result = MemoryQuery(bindings).status();

      expect(result, isA<MemoryStatusSucceeded>());
      final status = (result as MemoryStatusSucceeded).status;
      expect(status.totalBytes, 66158080000);
      expect(status.availableBytes, 47353069568);
    });

    test('surfaces a zero return as a failure', () {
      when(() => bindings.GlobalMemoryStatusEx(any())).thenReturn(0);

      final result = MemoryQuery(bindings).status();

      expect(result, isA<MemoryStatusFailed>());
      expect(
        (result as MemoryStatusFailed).failure.function,
        'GlobalMemoryStatusEx',
      );
    });
  });

  group('DiskQuery', () {
    late MockWindowsBindings bindings;

    setUp(() {
      bindings = MockWindowsBindings();
      when(() => bindings.GetLastError()).thenReturn(3);
      whenFormatMessage(bindings, 'The system cannot find the path specified.');
    });

    test('reports available, total and free bytes for the path', () {
      late String requested;
      when(
        () => bindings.GetDiskFreeSpaceExW(any(), any(), any(), any()),
      ).thenAnswer((invocation) {
        requested = readWideString(
          invocation.positionalArguments[0] as Pointer<WChar>,
        );
        setQuadPart(invocation.positionalArguments[1], 1407859671040);
        setQuadPart(invocation.positionalArguments[2], 2000398934016);
        setQuadPart(invocation.positionalArguments[3], 1407859671040);
        return 1;
      });

      final result = DiskQuery(bindings).space(r'C:\');

      expect(result, isA<DiskSpaceSucceeded>());
      final space = (result as DiskSpaceSucceeded).space;
      expect(requested, r'C:\');
      expect(space.availableBytes, 1407859671040);
      expect(space.totalBytes, 2000398934016);
      expect(space.freeBytes, 1407859671040);
    });

    test('surfaces a zero return as a failure', () {
      when(
        () => bindings.GetDiskFreeSpaceExW(any(), any(), any(), any()),
      ).thenReturn(0);

      final result = DiskQuery(bindings).space(r'Z:\nope');

      expect(result, isA<DiskSpaceFailed>());
      expect(
        (result as DiskSpaceFailed).failure.function,
        'GetDiskFreeSpaceExW',
      );
    });
  });

  group('HardLinkQuery', () {
    late MockWindowsBindings bindings;

    setUp(() {
      bindings = MockWindowsBindings();
      when(() => bindings.GetLastError()).thenReturn(183);
      whenFormatMessage(bindings, 'Cannot create a file when it exists.');
    });

    test('creates a hardlink from link to target', () {
      late String link;
      late String target;
      when(
        () => bindings.CreateHardLinkW(any(), any(), any()),
      ).thenAnswer((invocation) {
        link = readWideString(
          invocation.positionalArguments[0] as Pointer<WChar>,
        );
        target = readWideString(
          invocation.positionalArguments[1] as Pointer<WChar>,
        );
        return 1;
      });

      final result = HardLinkQuery(bindings).create(
        linkPath: r'C:\bin\ls.exe',
        targetPath: r'C:\bin\coreutils.exe',
      );

      expect(result, isA<HardLinkSucceeded>());
      expect(link, r'C:\bin\ls.exe');
      expect(target, r'C:\bin\coreutils.exe');
    });

    test('passes a null security-attributes pointer', () {
      when(
        () => bindings.CreateHardLinkW(any(), any(), any()),
      ).thenReturn(1);

      HardLinkQuery(bindings).create(
        linkPath: r'C:\bin\cat.exe',
        targetPath: r'C:\bin\coreutils.exe',
      );

      verify(
        () => bindings.CreateHardLinkW(any(), any(), nullptr),
      ).called(1);
    });

    test('surfaces a zero return as a failure', () {
      when(() => bindings.CreateHardLinkW(any(), any(), any())).thenReturn(0);

      final result = HardLinkQuery(bindings).create(
        linkPath: r'C:\bin\ls.exe',
        targetPath: r'C:\bin\coreutils.exe',
      );

      expect(result, isA<HardLinkFailed>());
      expect((result as HardLinkFailed).failure.function, 'CreateHardLinkW');
    });
  });

  group('ProcessorQuery', () {
    late MockWindowsBindings bindings;

    setUp(() {
      bindings = MockWindowsBindings();
      when(() => bindings.GetLastError()).thenReturn(87);
      whenFormatMessage(bindings, 'The parameter is incorrect.');
    });

    test('counts processors across every group', () {
      when(() => bindings.GetActiveProcessorCount(any())).thenReturn(12);

      final result = ProcessorQuery(bindings).activeCount();

      expect((result as ProcessorCountSucceeded).count, 12);
      verify(
        () => bindings.GetActiveProcessorCount(ALL_PROCESSOR_GROUPS),
      ).called(1);
    });

    test('surfaces a zero count as a failure', () {
      when(() => bindings.GetActiveProcessorCount(any())).thenReturn(0);

      final result = ProcessorQuery(bindings).activeCount();

      expect(result, isA<ProcessorCountFailed>());
      expect(
        (result as ProcessorCountFailed).failure.function,
        'GetActiveProcessorCount',
      );
    });
  });
}
