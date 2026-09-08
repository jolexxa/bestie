import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

void main() {
  final console = Pointer<Void>.fromAddress(0x99);
  final input = Pointer<Void>.fromAddress(0x10);
  final output = Pointer<Void>.fromAddress(0x20);
  final out = Pointer<HPCON>.fromAddress(0x30);

  Conpty stub({
    int Function(COORD, HANDLE, HANDLE, int, Pointer<HPCON>)? create,
    int Function(HPCON, COORD)? resize,
    void Function(HPCON)? close,
  }) => Conpty(
    create: create ?? (_, _, _, _, _) => 0,
    resize: resize ?? (_, _) => 0,
    close: close ?? (_) {},
  );

  test('forwards each call to the entry point it was given', () {
    HPCON? closed;
    HPCON? resized;
    var flags = 0;
    final conpty = stub(
      create: (size, hInput, hOutput, dwFlags, phPC) {
        flags = dwFlags;
        return 1;
      },
      resize: (hPC, size) {
        resized = hPC;
        return 2;
      },
      close: (hPC) => closed = hPC,
    );
    final size = calloc<COORD>();

    expect(conpty.createPseudoConsole(size.ref, input, output, 8, out), 1);
    expect(conpty.resizePseudoConsole(console, size.ref), 2);
    conpty.closePseudoConsole(console);

    expect(flags, 8);
    expect(resized, console);
    expect(closed, console);
    calloc.free(size);
  });

  test('opening carries either the entry points or why there are none', () {
    final conpty = stub();

    expect(ConptyOpenSucceeded(conpty).conpty, same(conpty));
    expect(const ConptyOpenFailed('no such file').reason, 'no such file');
  });
}
