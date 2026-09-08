import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

/// Decodes a UTF-16 `key=value\0…\0\0` environment block, or null for a null
/// pointer. Read while the block is still allocated — `ChildProcess.start`
/// frees it once `CreateProcessW` returns.
Map<String, String>? decodeEnvironment(Pointer<Void> block) {
  if (block == nullptr) return null;
  final words = block.cast<Uint16>();
  final units = <int>[];
  for (var i = 0; !(words[i] == 0 && words[i + 1] == 0); i++) {
    units.add(words[i]);
  }
  final environment = <String, String>{};
  for (final entry in String.fromCharCodes(units).split('\u0000')) {
    if (entry.isEmpty) continue;
    final eq = entry.indexOf('=');
    environment[entry.substring(0, eq)] = entry.substring(eq + 1);
  }
  return environment;
}

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;
  late AttributeList attributeList;

  // Read inside the stub, where the allocations are still live.
  int? startupFlags;
  int? inheritHandles;
  Map<String, String>? environment;
  var environmentPassed = false;

  setUp(() {
    bindings = MockWindowsBindings();
    startupFlags = inheritHandles = null;
    environment = null;
    environmentPassed = false;
    when(
      () => bindings.CreateProcessW(
        any(),
        any(),
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
      inheritHandles = invocation.positionalArguments[4] as int;
      startupFlags = invocation.positionalArguments[5] as int;
      environmentPassed = true;
      environment = decodeEnvironment(
        invocation.positionalArguments[6] as Pointer<Void>,
      );
      (invocation.positionalArguments[9] as Pointer<PROCESS_INFORMATION>).ref
        ..hProcess = Pointer<Void>.fromAddress(0xA0)
        ..hThread = Pointer<Void>.fromAddress(0xB0)
        ..dwProcessId = 4242;
      return 1;
    });
    when(() => bindings.TerminateProcess(any(), any())).thenReturn(1);
    when(() => bindings.CloseHandle(any())).thenReturn(1);
    when(() => bindings.GetLastError()).thenReturn(2);
    whenFormatMessage(bindings, 'The system cannot find the file specified.');

    // A stand-in attribute list; ChildProcess only forwards its pointer.
    when(
      () => bindings.InitializeProcThreadAttributeList(
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenAnswer((invocation) {
      (invocation.positionalArguments[3] as Pointer<UnsignedLongLong>).value =
          48;
      return invocation.positionalArguments[0] == nullptr ? 0 : 1;
    });
    when(
      () => bindings.UpdateProcThreadAttribute(
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenReturn(1);
    when(() => bindings.DeleteProcThreadAttributeList(any())).thenReturn(null);
    attributeList =
        (AttributeLists(bindings).build(const []) as AttributeListSucceeded)
            .attributeList;
  });

  ChildProcess start({
    Map<String, String>? environment,
    bool inheritHandles = false,
    Win32Handle? stdInput,
    Win32Handle? stdOutput,
    Win32Handle? stdError,
  }) =>
      (ChildProcesses(bindings).start(
                commandLine: '"C:/bash.exe" -i',
                attributeList: attributeList,
                environment: environment,
                inheritHandles: inheritHandles,
                stdInput: stdInput,
                stdOutput: stdOutput,
                stdError: stdError,
              )
              as ChildProcessStartSucceeded)
          .process;

  group('ChildProcess.start', () {
    test('launches with an extended startup info and reports the pid', () {
      final result = ChildProcesses(bindings).start(
        commandLine: '"C:/bash.exe" -i',
        attributeList: attributeList,
      );

      final process = (result as ChildProcessStartSucceeded).process;
      expect(process.pid, 4242);
      // The process handle, not the thread handle — waiting on the wrong one
      // would report an exit the moment the main thread ends.
      expect(process.processHandle.address, 0xA0);
      expect(startupFlags! & EXTENDED_STARTUPINFO_PRESENT, isNonZero);
    });

    test('does not inherit handles in the ConPTY case', () {
      start();

      expect(inheritHandles, 0);
    });

    test('inherits handles and flags a unicode environment in piped mode', () {
      start(
        environment: const {'TERM': 'xterm-256color'},
        inheritHandles: true,
        stdInput: Win32Handle(Pointer.fromAddress(0x1)),
        stdOutput: Win32Handle(Pointer.fromAddress(0x2)),
        stdError: Win32Handle(Pointer.fromAddress(0x3)),
      );

      expect(inheritHandles, 1);
      expect(startupFlags! & CREATE_UNICODE_ENVIRONMENT, isNonZero);
    });

    test('encodes the environment as a NUL-delimited block', () {
      start(environment: const {'A': '1', 'B': '2'});

      expect(environment, {'A': '1', 'B': '2'});
    });

    test('passes no environment block when none is given', () {
      start();

      expect(environmentPassed, isTrue);
      expect(environment, isNull);
    });

    test('fails when the process cannot be created', () {
      when(
        () => bindings.CreateProcessW(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(0);

      final result = ChildProcesses(bindings).start(
        commandLine: 'nope',
        attributeList: attributeList,
      );

      expect(
        (result as ChildProcessStartFailed).failure.function,
        'CreateProcessW',
      );
    });
  });

  group('ChildProcess.terminate', () {
    test('terminates with the given exit code', () {
      final result = start().terminate(exitCode: 7);

      expect(result, isA<ChildTerminateSucceeded>());
      verify(
        () => bindings.TerminateProcess(
          any(that: predicate<HANDLE>((h) => h.address == 0xA0)),
          7,
        ),
      ).called(1);
    });

    test('fails when the process cannot be terminated', () {
      when(() => bindings.TerminateProcess(any(), any())).thenReturn(0);

      final result = start().terminate();

      expect(
        (result as ChildTerminateFailed).failure.function,
        'TerminateProcess',
      );
    });
  });

  group('ChildProcess.close', () {
    test('closes the process and thread handles exactly once', () {
      start()
        ..close()
        ..close();

      verify(
        () => bindings.CloseHandle(
          any(that: predicate<HANDLE>((h) => h.address == 0xA0)),
        ),
      ).called(1);
      verify(
        () => bindings.CloseHandle(
          any(that: predicate<HANDLE>((h) => h.address == 0xB0)),
        ),
      ).called(1);
    });
  });
}
