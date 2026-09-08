// coverage:ignore-file
//
// Opening DLLs and resolving symbols cannot be mocked, and only resolves at
// all on a Windows host.

import 'dart:ffi';

import 'package:win32_dart/src/bindings/windows_bindings.dart';

/// The DLLs bestie's Win32 surface spans, searched in order.
///
/// ffigen resolves each symbol lazily on first use, so a single-DLL handle
/// would throw at the first CRT or clipboard call rather than at startup.
class Win32Libraries {
  factory Win32Libraries() => _instance;
  Win32Libraries._();

  static final Win32Libraries _instance = Win32Libraries._();

  late final List<DynamicLibrary> _libraries = [
    DynamicLibrary.open('kernel32.dll'),
    DynamicLibrary.open('kernelbase.dll'),
    DynamicLibrary.open('ucrtbase.dll'),
    DynamicLibrary.open('advapi32.dll'),
    DynamicLibrary.open('user32.dll'),
    DynamicLibrary.open('userenv.dll'),
    DynamicLibrary.open('ole32.dll'),
    DynamicLibrary.open('shell32.dll'),
  ];

  /// Returns the first loaded DLL exporting [symbol].
  ///
  /// A missing symbol means the process is not a supported Windows build,
  /// which is not a condition callers can recover from.
  Pointer<T> lookup<T extends NativeType>(String symbol) {
    for (final library in _libraries) {
      if (library.providesSymbol(symbol)) return library.lookup<T>(symbol);
    }
    throw ArgumentError('No loaded DLL exports "$symbol".');
  }

  /// Whether any loaded DLL exports [symbol].
  bool provides(String symbol) =>
      _libraries.any((library) => library.providesSymbol(symbol));
}

/// The host's Win32 and CRT bindings. Lazy — nothing opens a DLL until the
/// first call.
final WindowsBindings win32 =
    WindowsBindings.fromLookup(Win32Libraries().lookup)
      // Resolving the symbol clears the thread-local last error, so a
      // GetLastError that resolves it would report success after a failure.
      ..GetLastError();

/// Whether the host exports [symbol] — false on a Windows too old to carry
/// it, e.g. `CreatePseudoConsole` before build 17763.
bool win32Provides(String symbol) => Win32Libraries().provides(symbol);
