// coverage:ignore-file
//
// Opening a DLL and resolving symbols out of it cannot be mocked, and only
// resolves at all on a Windows host. What the resolved entry points are then
// used for lives in conpty.dart, which is covered.

import 'dart:ffi';

import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/console/conpty.dart';

/// Opens the `conpty.dll` bestie ships and resolves its entry points.
class ConptyLibraries {
  const ConptyLibraries();

  /// The exports carry a `Conpty` prefix, because the library also has to
  /// coexist with the identically-named kernel32 ones.
  static const _create = 'ConptyCreatePseudoConsole';
  static const _resize = 'ConptyResizePseudoConsole';
  static const _close = 'ConptyClosePseudoConsole';

  /// Opens the `conpty.dll` at [libraryPath].
  ///
  /// The library finds the console host it launches by looking beside itself,
  /// so [libraryPath] has to name the copy that ships with `OpenConsole.exe`.
  /// A library on its own would quietly fall back to the `conhost.exe` that
  /// came with Windows, which is exactly what shipping one is meant to avoid.
  ConptyOpenResult open(String libraryPath) {
    final DynamicLibrary library;
    try {
      library = DynamicLibrary.open(libraryPath);
      // A library that will not load reaches Dart as an ArgumentError, so
      // that is the only thing there is to catch.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (error) {
      return ConptyOpenFailed('could not open $libraryPath: ${error.message}');
    }

    for (final symbol in [_create, _resize, _close]) {
      if (!library.providesSymbol(symbol)) {
        return ConptyOpenFailed('$libraryPath does not export $symbol.');
      }
    }

    return ConptyOpenSucceeded(
      Conpty(
        create: library
            .lookup<
              NativeFunction<
                Long Function(
                  COORD,
                  HANDLE,
                  HANDLE,
                  UnsignedLong,
                  Pointer<HPCON>,
                )
              >
            >(_create)
            .asFunction(),
        resize: library
            .lookup<NativeFunction<Long Function(HPCON, COORD)>>(_resize)
            .asFunction(),
        close: library
            .lookup<NativeFunction<Void Function(HPCON)>>(_close)
            .asFunction(),
      ),
    );
  }
}
