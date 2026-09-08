import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';

/// The generated bindings class is not final, so it mocks directly.
class MockWindowsBindings extends Mock implements WindowsBindings {}

/// Helpers for stubbing calls that report through an out-parameter, which
/// mocktail cannot express with a return value alone.

/// Registers the pointer types `any()` is used for across the suite.
void registerPointerFallbacks() {
  registerFallbackValue(Pointer<Void>.fromAddress(0));
  registerFallbackValue(Pointer<Int>.fromAddress(0));
  registerFallbackValue(Pointer<Char>.fromAddress(0));
  registerFallbackValue(Pointer<WChar>.fromAddress(0));
  registerFallbackValue(Pointer<Pointer<Char>>.fromAddress(0));
  registerFallbackValue(Pointer<Pointer<Void>>.fromAddress(0));
  registerFallbackValue(Pointer<UnsignedLong>.fromAddress(0));
  registerFallbackValue(Pointer<UnsignedLongLong>.fromAddress(0));
  registerFallbackValue(Pointer<SECURITY_ATTRIBUTES>.fromAddress(0));
  registerFallbackValue(Pointer<MEMORYSTATUSEX>.fromAddress(0));
  registerFallbackValue(Pointer<ULARGE_INTEGER>.fromAddress(0));
  registerFallbackValue(Pointer<HWND__>.fromAddress(0));
  registerFallbackValue(Pointer<STARTUPINFOW>.fromAddress(0));
  registerFallbackValue(Pointer<PROCESS_INFORMATION>.fromAddress(0));
  registerFallbackValue(Pointer<PROC_THREAD_ATTRIBUTE_LIST>.fromAddress(0));
  registerFallbackValue(Pointer<OVERLAPPED>.fromAddress(0));
  registerFallbackValue(Pointer<ACL>.fromAddress(0));
  registerFallbackValue(Pointer<Pointer<ACL>>.fromAddress(0));
  registerFallbackValue(Pointer<EXPLICIT_ACCESS_W>.fromAddress(0));
  registerFallbackValue(Pointer<Pointer<EXPLICIT_ACCESS_W>>.fromAddress(0));
  registerFallbackValue(Pointer<Pointer<WChar>>.fromAddress(0));
  registerFallbackValue(Pointer<SHELLEXECUTEINFOW>.fromAddress(0));
  registerFallbackValue(SE_OBJECT_TYPE.SE_FILE_OBJECT);
  // CreatePseudoConsole / ResizePseudoConsole take a COORD by value; a
  // heap-backed instance stands in for `any()`.
  registerFallbackValue(calloc<COORD>().ref);
}

/// Writes [value] into a UTF-16 out-parameter, NUL-terminated.
void writeWide(Pointer<WChar> buffer, String value) {
  final units = buffer.cast<Uint16>();
  for (var i = 0; i < value.length; i++) {
    units[i] = value.codeUnitAt(i);
  }
  units[value.length] = 0;
}

/// Writes [value] into a single-byte out-parameter, NUL-terminated.
void writeBytes(Pointer<Char> buffer, String value) {
  final units = buffer.cast<Uint8>();
  for (var i = 0; i < value.length; i++) {
    units[i] = value.codeUnitAt(i);
  }
  units[value.length] = 0;
}

/// Stubs `FormatMessageW` to report [message].
void whenFormatMessage(WindowsBindings bindings, String message) {
  when(
    () => bindings.FormatMessageW(
      any(),
      any(),
      any(),
      any(),
      any(),
      any(),
      any(),
    ),
  ).thenAnswer((invocation) {
    writeWide(invocation.positionalArguments[4] as Pointer<WChar>, message);
    return message.length;
  });
}

/// Stubs `_get_errno` to report [errno].
void whenGetErrno(WindowsBindings bindings, int errno) {
  when(() => bindings.get_errno(any())).thenAnswer((invocation) {
    (invocation.positionalArguments[0] as Pointer<Int>).value = errno;
    return 0;
  });
}

/// Stubs `strerror_s` to report [message].
void whenStrerror(WindowsBindings bindings, String message) {
  when(() => bindings.strerror_s(any(), any(), any())).thenAnswer((invocation) {
    writeBytes(invocation.positionalArguments[0] as Pointer<Char>, message);
    return 0;
  });
}

/// Writes [value] into a `ULARGE_INTEGER` out-parameter.
void setQuadPart(Object? argument, int value) =>
    (argument! as Pointer<ULARGE_INTEGER>).ref.QuadPart = value;

/// Stubs `GetConsoleMode` to report [mode].
void whenConsoleMode(WindowsBindings bindings, int mode) {
  when(() => bindings.GetConsoleMode(any(), any())).thenAnswer((invocation) {
    (invocation.positionalArguments[1] as Pointer<UnsignedLong>).value = mode;
    return 1;
  });
}
