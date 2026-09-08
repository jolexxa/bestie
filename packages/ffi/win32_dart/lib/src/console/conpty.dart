import 'dart:ffi';

import 'package:win32_dart/src/bindings/windows_bindings.dart';

/// The pseudoconsole entry points, resolved out of the `conpty.dll` bestie
/// ships.
///
/// Windows exports the same API from kernel32, but those entry points run
/// whichever `conhost.exe` the machine came with. This can be a host
/// that repaints its whole viewport after a resize and, having no
/// scrollback, paints an orphaned line tail over history it has already
/// forgotten.
///
/// Instead, we ship Microsoft's redistributable ConPTY and the
/// `OpenConsole.exe` that comes with it, which reflows and redraws only
/// the prompt.
class Conpty {
  /// Wraps entry points resolved from a loaded `conpty.dll`.
  const Conpty({
    required int Function(COORD, HANDLE, HANDLE, int, Pointer<HPCON>) create,
    required int Function(HPCON, COORD) resize,
    required void Function(HPCON) close,
  }) : _create = create,
       _resize = resize,
       _close = close;

  final int Function(COORD, HANDLE, HANDLE, int, Pointer<HPCON>) _create;
  final int Function(HPCON, COORD) _resize;
  final void Function(HPCON) _close;

  /// `ConptyCreatePseudoConsole`.
  int createPseudoConsole(
    COORD size,
    HANDLE input,
    HANDLE output,
    int flags,
    Pointer<HPCON> out,
  ) => _create(size, input, output, flags, out);

  /// `ConptyResizePseudoConsole`.
  int resizePseudoConsole(HPCON console, COORD size) => _resize(console, size);

  /// `ConptyClosePseudoConsole`.
  void closePseudoConsole(HPCON console) => _close(console);
}

sealed class ConptyOpenResult {
  const ConptyOpenResult();
}

final class ConptyOpenSucceeded extends ConptyOpenResult {
  const ConptyOpenSucceeded(this.conpty);
  final Conpty conpty;
}

final class ConptyOpenFailed extends ConptyOpenResult {
  const ConptyOpenFailed(this.reason);

  /// Why the library could not be used, for a message the user can act on.
  final String reason;
}
