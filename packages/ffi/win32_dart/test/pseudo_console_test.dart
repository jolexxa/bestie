import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

/// A console routed at the mocked Win32 entry points, so these tests still
/// exercise the real struct marshalling on the way through.
Conpty _conpty(MockWindowsBindings bindings) => Conpty(
  create: bindings.CreatePseudoConsole,
  resize: bindings.ResizePseudoConsole,
  close: bindings.ClosePseudoConsole,
);

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;

  final input = Pointer<Void>.fromAddress(0x10);
  final output = Pointer<Void>.fromAddress(0x20);

  // The COORD is passed by value and freed after the call returns, so its
  // dimensions are read while still live, inside the stub.
  int? createdCols;
  int? createdRows;
  int? resizedCols;
  int? resizedRows;

  /// Stubs `CreatePseudoConsole` to hand back [pcon] as the HPCON.
  void whenCreate({int pcon = 0x99, int result = 0}) {
    when(
      () => bindings.CreatePseudoConsole(any(), any(), any(), any(), any()),
    ).thenAnswer((invocation) {
      final size = invocation.positionalArguments[0] as COORD;
      createdCols = size.X;
      createdRows = size.Y;
      (invocation.positionalArguments[4] as Pointer<HPCON>).value =
          Pointer<Void>.fromAddress(pcon);
      return result;
    });
  }

  setUp(() {
    bindings = MockWindowsBindings();
    createdCols = createdRows = resizedCols = resizedRows = null;
    whenCreate();
    when(() => bindings.ResizePseudoConsole(any(), any())).thenAnswer((
      invocation,
    ) {
      final size = invocation.positionalArguments[1] as COORD;
      resizedCols = size.X;
      resizedRows = size.Y;
      return 0;
    });
    when(() => bindings.ClosePseudoConsole(any())).thenReturn(null);
  });

  PseudoConsole create() =>
      (PseudoConsoles(_conpty(bindings)).open(
                rows: 24,
                cols: 80,
                input: input,
                output: output,
              )
              as PseudoConsoleCreateSucceeded)
          .console;

  group('PseudoConsole.create', () {
    test('opens a console sized cols by rows over the given pipe ends', () {
      final result = PseudoConsoles(_conpty(bindings)).open(
        rows: 24,
        cols: 80,
        input: input,
        output: output,
      );

      expect(result, isA<PseudoConsoleCreateSucceeded>());
      final console = (result as PseudoConsoleCreateSucceeded).console;
      expect(console.handle.address, 0x99);
      expect(console.isClosed, isFalse);
      expect(createdCols, 80);
      expect(createdRows, 24);
      verify(
        () => bindings.CreatePseudoConsole(
          any(),
          input,
          output,
          0,
          any(),
        ),
      ).called(1);
    });

    test('fails with the HRESULT when the console cannot be created', () {
      whenCreate(result: 0x80070057);

      final result = PseudoConsoles(_conpty(bindings)).open(
        rows: 24,
        cols: 80,
        input: input,
        output: output,
      );

      final failure = (result as PseudoConsoleCreateFailed).failure;
      expect(failure.function, 'CreatePseudoConsole');
      expect(failure.code, 0x80070057);
      expect(failure.channel, Win32ErrorChannel.none);
    });
  });

  group('PseudoConsole.resize', () {
    test('resizes to the new dimensions', () {
      final result = create().resize(rows: 30, cols: 120);

      expect(result, isA<PseudoConsoleResizeSucceeded>());
      expect(resizedCols, 120);
      expect(resizedRows, 30);
    });

    test('fails with the HRESULT when the resize is refused', () {
      when(
        () => bindings.ResizePseudoConsole(any(), any()),
      ).thenReturn(0x80004005);

      final result = create().resize(rows: 30, cols: 120);

      expect(
        (result as PseudoConsoleResizeFailed).failure.function,
        'ResizePseudoConsole',
      );
    });

    test('refuses once the console is closed', () {
      final console = create()..close();

      final result = console.resize(rows: 30, cols: 120);

      expect(
        (result as PseudoConsoleResizeFailed).failure.message,
        'pseudoconsole is closed',
      );
      verifyNever(() => bindings.ResizePseudoConsole(any(), any()));
    });
  });

  group('PseudoConsole.close', () {
    test('closes the console exactly once', () {
      create()
        ..close()
        ..close();

      verify(() => bindings.ClosePseudoConsole(any())).called(1);
    });
  });
}
