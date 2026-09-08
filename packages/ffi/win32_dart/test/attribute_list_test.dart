import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/bindings/windows_bindings.dart';
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

  setUp(() {
    bindings = MockWindowsBindings();
    // The size-query call (null list) reports a byte count and "fails"; the
    // real init call (non-null list) succeeds.
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
      final list =
          invocation.positionalArguments[0]
              as Pointer<PROC_THREAD_ATTRIBUTE_LIST>;
      return list == nullptr ? 0 : 1;
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
    when(
      () => bindings.DeleteProcThreadAttributeList(any()),
    ).thenReturn(null);
    when(() => bindings.ClosePseudoConsole(any())).thenReturn(null);
    when(() => bindings.GetLastError()).thenReturn(1);
    whenFormatMessage(bindings, 'Incorrect function.');
  });

  PseudoConsole pseudoConsole({int handle = 0x99}) {
    when(
      () => bindings.CreatePseudoConsole(any(), any(), any(), any(), any()),
    ).thenAnswer((invocation) {
      (invocation.positionalArguments[4] as Pointer<HPCON>).value =
          Pointer<Void>.fromAddress(handle);
      return 0;
    });
    return (PseudoConsoles(_conpty(bindings)).open(
              rows: 24,
              cols: 80,
              input: Pointer<Void>.fromAddress(0x10),
              output: Pointer<Void>.fromAddress(0x20),
            )
            as PseudoConsoleCreateSucceeded)
        .console;
  }

  group('ProcThreadAttribute.pseudoConsole', () {
    test('wires the pseudoconsole handle as the one attribute', () {
      final result = AttributeLists(bindings).build([
        ProcThreadAttribute.pseudoConsole(pseudoConsole()),
      ]);

      expect(result, isA<AttributeListSucceeded>());
      final value =
          verify(
                () => bindings.UpdateProcThreadAttribute(
                  any(),
                  0,
                  procThreadAttributePseudoconsole,
                  captureAny(),
                  sizeOf<HANDLE>(),
                  nullptr,
                  nullptr,
                ),
              ).captured.single
              as Pointer<Void>;
      expect(value.address, 0x99);
    });

    test('initialises the list before updating it', () {
      AttributeLists(bindings).build([
        ProcThreadAttribute.pseudoConsole(pseudoConsole()),
      ]);

      verifyInOrder([
        () => bindings.InitializeProcThreadAttributeList(
          any(that: isNot(nullptr)),
          any(),
          any(),
          any(),
        ),
        () => bindings.UpdateProcThreadAttribute(
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
          any(),
        ),
      ]);
    });
  });

  group('ProcThreadAttribute.handleList', () {
    test('wires the handle list sized to the set', () {
      AttributeLists(bindings).build([
        ProcThreadAttribute.handleList([
          Win32Handle(Pointer.fromAddress(0x10)),
          Win32Handle(Pointer.fromAddress(0x20)),
        ]),
      ]);

      verify(
        () => bindings.UpdateProcThreadAttribute(
          any(),
          0,
          procThreadAttributeHandleList,
          any(),
          2 * sizeOf<HANDLE>(),
          nullptr,
          nullptr,
        ),
      ).called(1);
    });
  });

  group('several attributes', () {
    test('sizes the list to the number of attributes', () {
      AttributeLists(bindings).build([
        ProcThreadAttribute.pseudoConsole(pseudoConsole()),
        ProcThreadAttribute.handleList([
          Win32Handle(Pointer.fromAddress(0x10)),
        ]),
      ]);

      verify(
        () => bindings.InitializeProcThreadAttributeList(
          any(that: isNot(nullptr)),
          2,
          any(),
          any(),
        ),
      ).called(1);
    });

    test('writes every attribute, in the order given', () {
      AttributeLists(bindings).build([
        ProcThreadAttribute.pseudoConsole(pseudoConsole()),
        ProcThreadAttribute.handleList([
          Win32Handle(Pointer.fromAddress(0x10)),
        ]),
      ]);

      final written = verify(
        () => bindings.UpdateProcThreadAttribute(
          any(),
          any(),
          captureAny(),
          any(),
          any(),
          any(),
          any(),
        ),
      ).captured.cast<int>();
      expect(written, [
        procThreadAttributePseudoconsole,
        procThreadAttributeHandleList,
      ]);
    });

    test('an empty list asks for no attributes and writes none', () {
      expect(
        AttributeLists(bindings).build(const []),
        isA<AttributeListSucceeded>(),
      );

      verify(
        () => bindings.InitializeProcThreadAttributeList(
          any(that: isNot(nullptr)),
          0,
          any(),
          any(),
        ),
      ).called(1);
      verifyNever(
        () => bindings.UpdateProcThreadAttribute(
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
  });

  group('failure paths', () {
    test('stops at the attribute that is refused', () {
      var updates = 0;
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
      ).thenAnswer((_) => ++updates == 1 ? 1 : 0);

      final result = AttributeLists(bindings).build([
        ProcThreadAttribute.pseudoConsole(pseudoConsole()),
        ProcThreadAttribute.handleList([
          Win32Handle(Pointer.fromAddress(0x10)),
        ]),
        ProcThreadAttribute.handleList([
          Win32Handle(Pointer.fromAddress(0x20)),
        ]),
      ]);

      expect(result, isA<AttributeListFailed>());
      expect(updates, 2);
      verify(() => bindings.DeleteProcThreadAttributeList(any())).called(1);
    });

    test('fails and frees when the list cannot be initialised', () {
      when(
        () => bindings.InitializeProcThreadAttributeList(
          any(that: isNot(nullptr)),
          any(),
          any(),
          any(),
        ),
      ).thenReturn(0);

      final result = AttributeLists(bindings).build([
        ProcThreadAttribute.pseudoConsole(pseudoConsole()),
      ]);

      expect(
        (result as AttributeListFailed).failure.function,
        'InitializeProcThreadAttributeList',
      );
      verifyNever(
        () => bindings.UpdateProcThreadAttribute(
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

    test('deletes the list when the attribute update is refused', () {
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
      ).thenReturn(0);

      final result = AttributeLists(bindings).build([
        ProcThreadAttribute.pseudoConsole(pseudoConsole()),
      ]);

      expect(
        (result as AttributeListFailed).failure.function,
        'UpdateProcThreadAttribute',
      );
      verify(() => bindings.DeleteProcThreadAttributeList(any())).called(1);
    });
  });

  group('AttributeList.close', () {
    test('deletes the list exactly once', () {
      final list =
          (AttributeLists(bindings).build([
                    ProcThreadAttribute.pseudoConsole(pseudoConsole()),
                  ])
                  as AttributeListSucceeded)
              .attributeList
            ..close()
            ..close();

      expect(list.pointer, isNot(nullptr));
      verify(() => bindings.DeleteProcThreadAttributeList(any())).called(1);
    });
  });
}
