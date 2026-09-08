import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

/// Stands in for the moveable block `GlobalAlloc` hands back.
final _block = Pointer<Void>.fromAddress(0x2b0);

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;
  late Pointer<Uint16> memory;

  /// The bytes the session locked and wrote into, as UTF-16 code units.
  List<int> written(int length) => memory.asTypedList(length).toList();

  setUp(() {
    bindings = MockWindowsBindings();
    // Real memory, so the session's writes can be read back.
    memory = calloc<Uint16>(64);

    when(() => bindings.OpenClipboard(any())).thenReturn(1);
    when(() => bindings.EmptyClipboard()).thenReturn(1);
    when(() => bindings.GlobalAlloc(any(), any())).thenReturn(_block);
    when(() => bindings.GlobalLock(any())).thenReturn(memory.cast<Void>());
    when(() => bindings.GlobalUnlock(any())).thenReturn(0);
    when(
      () => bindings.SetClipboardData(any(), any()),
    ).thenReturn(_block);
    when(() => bindings.CloseClipboard()).thenReturn(1);
    when(() => bindings.GlobalFree(any())).thenReturn(nullptr);
    when(() => bindings.GetLastError()).thenReturn(5);
    whenFormatMessage(bindings, 'Access is denied.');
  });

  tearDown(() => calloc.free(memory));

  ClipboardSession openSession() =>
      (Clipboard(bindings).open() as ClipboardOpenSucceeded).session;

  group('ClipboardSession.open', () {
    test('holds the clipboard for the calling process', () {
      final result = Clipboard(bindings).open();

      expect(result, isA<ClipboardOpenSucceeded>());
      expect((result as ClipboardOpenSucceeded).session.isClosed, isFalse);
      verify(() => bindings.OpenClipboard(nullptr)).called(1);
    });

    test('fails when another process is holding it', () {
      when(() => bindings.OpenClipboard(any())).thenReturn(0);

      final result = Clipboard(bindings).open();

      expect(result, isA<ClipboardOpenFailed>());
      final failure = (result as ClipboardOpenFailed).failure;
      expect(failure.function, 'OpenClipboard');
      expect(failure.code, 5);
    });
  });

  group('ClipboardSession.writeUnicodeText', () {
    test('stores the text as NUL-terminated UTF-16', () {
      final result = openSession().writeUnicodeText('cow');

      expect(result, isA<ClipboardWriteSucceeded>());
      expect(written(4), [0x63, 0x6f, 0x77, 0]);
      verify(() => bindings.GlobalAlloc(GMEM_MOVEABLE, 8)).called(1);
      verify(() => bindings.SetClipboardData(CF_UNICODETEXT, _block)).called(1);
    });

    test('leaves the stored block alone — the system owns it now', () {
      openSession().writeUnicodeText('cow');

      verifyNever(() => bindings.GlobalFree(any()));
    });

    test('claims ownership before storing anything', () {
      openSession().writeUnicodeText('cow');

      verifyInOrder([
        () => bindings.EmptyClipboard(),
        () => bindings.GlobalAlloc(any(), any()),
        () => bindings.SetClipboardData(any(), any()),
      ]);
    });

    test('writes only a terminator for empty text', () {
      final result = openSession().writeUnicodeText('');

      expect(result, isA<ClipboardWriteSucceeded>());
      expect(written(1), [0]);
      verify(() => bindings.GlobalAlloc(GMEM_MOVEABLE, 2)).called(1);
    });

    test('carries text outside the basic plane through as surrogates', () {
      openSession().writeUnicodeText('🐄');

      expect(written(3), [0xd83d, 0xdc04, 0]);
    });

    test('fails without allocating when ownership is refused', () {
      when(() => bindings.EmptyClipboard()).thenReturn(0);

      final result = openSession().writeUnicodeText('cow');

      expect(
        (result as ClipboardWriteFailed).failure.function,
        'EmptyClipboard',
      );
      verifyNever(() => bindings.GlobalAlloc(any(), any()));
    });

    test('fails without locking when the block cannot be allocated', () {
      when(() => bindings.GlobalAlloc(any(), any())).thenReturn(nullptr);

      final result = openSession().writeUnicodeText('cow');

      expect((result as ClipboardWriteFailed).failure.function, 'GlobalAlloc');
      verifyNever(() => bindings.GlobalLock(any()));
    });

    test('frees the block when it cannot be locked', () {
      when(() => bindings.GlobalLock(any())).thenReturn(nullptr);

      final result = openSession().writeUnicodeText('cow');

      expect((result as ClipboardWriteFailed).failure.function, 'GlobalLock');
      verify(() => bindings.GlobalFree(_block)).called(1);
      verifyNever(() => bindings.SetClipboardData(any(), any()));
    });

    test('frees the block when the store is refused — we still own it', () {
      when(() => bindings.SetClipboardData(any(), any())).thenReturn(nullptr);

      final result = openSession().writeUnicodeText('cow');

      expect(
        (result as ClipboardWriteFailed).failure.function,
        'SetClipboardData',
      );
      verify(() => bindings.GlobalFree(_block)).called(1);
    });

    test('refuses once the session is closed', () {
      final session = openSession()..close();

      final result = session.writeUnicodeText('cow');

      final failure = (result as ClipboardWriteFailed).failure;
      expect(failure.channel, Win32ErrorChannel.none);
      expect(failure.message, 'clipboard session is closed');
      verifyNever(() => bindings.EmptyClipboard());
    });
  });

  group('ClipboardSession.close', () {
    test('releases the clipboard exactly once', () {
      final session = openSession();

      expect(session.close(), isA<ClipboardCloseSucceeded>());
      expect(session.close(), isA<ClipboardCloseSucceeded>());
      expect(session.isClosed, isTrue);
      verify(() => bindings.CloseClipboard()).called(1);
    });

    test('stays open when the release is refused', () {
      when(() => bindings.CloseClipboard()).thenReturn(0);
      final session = openSession();

      final result = session.close();

      expect(
        (result as ClipboardCloseFailed).failure.function,
        'CloseClipboard',
      );
      expect(session.isClosed, isFalse);
    });
  });
}
