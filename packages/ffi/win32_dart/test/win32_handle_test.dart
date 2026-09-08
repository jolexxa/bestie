import 'dart:ffi';

import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

void main() {
  group('Win32Handle treats every failure sentinel as invalid', () {
    test('NULL, as GlobalAlloc returns', () {
      expect(Win32Handle(Pointer<Void>.fromAddress(0)).isValid, isFalse);
    });

    test('INVALID_HANDLE_VALUE, as CreateFileW returns', () {
      expect(Win32Handle(Pointer<Void>.fromAddress(-1)).isValid, isFalse);
    });
  });

  test('a real handle is valid', () {
    expect(Win32Handle(Pointer<Void>.fromAddress(0x1a0)).isValid, isTrue);
  });

  test('a handle is usable as the HANDLE it wraps', () {
    final handle = Win32Handle(Pointer<Void>.fromAddress(0x1a0));

    expect(handle.address, 0x1a0);
  });
}
