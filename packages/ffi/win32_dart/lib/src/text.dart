import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// UTF-16 and single-byte marshalling for the `Pointer<WChar>` and
/// `Pointer<Char>` arguments the generated bindings take.

/// Calls [body] with [value] as a NUL-terminated UTF-16 string.
R withWideString<R>(String value, R Function(Pointer<WChar>) body) {
  final pointer = value.toNativeUtf16(allocator: calloc);
  try {
    return body(pointer.cast<WChar>());
  } finally {
    calloc.free(pointer);
  }
}

/// Calls [body] with a zeroed buffer of [length] UTF-16 code units.
R withWideBuffer<R>(int length, R Function(Pointer<WChar>) body) {
  final buffer = calloc<Uint16>(length);
  try {
    return body(buffer.cast<WChar>());
  } finally {
    calloc.free(buffer);
  }
}

/// Calls [body] with a zeroed buffer of [length] bytes.
R withByteBuffer<R>(int length, R Function(Pointer<Char>) body) {
  final buffer = calloc<Uint8>(length);
  try {
    return body(buffer.cast<Char>());
  } finally {
    calloc.free(buffer);
  }
}

/// Reads a NUL-terminated UTF-16 string.
String readWideString(Pointer<WChar> pointer) =>
    pointer.cast<Utf16>().toDartString();

/// Reads a NUL-terminated single-byte string.
String readByteString(Pointer<Char> pointer) =>
    pointer.cast<Utf8>().toDartString();
