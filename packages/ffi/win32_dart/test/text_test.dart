import 'package:test/test.dart';
import 'package:win32_dart/src/text.dart';

import 'native_stubs.dart';

void main() {
  test('withWideString round-trips a string through UTF-16', () {
    final read = withWideString(r'C:\Users\cow\native.log', readWideString);

    expect(read, r'C:\Users\cow\native.log');
  });

  test('withWideBuffer hands out a zeroed buffer', () {
    final read = withWideBuffer(32, (buffer) {
      expect(readWideString(buffer), isEmpty);
      writeWide(buffer, 'Access is denied.');
      return readWideString(buffer);
    });

    expect(read, 'Access is denied.');
  });

  test('withByteBuffer hands out a zeroed buffer', () {
    final read = withByteBuffer(32, (buffer) {
      expect(readByteString(buffer), isEmpty);
      writeBytes(buffer, 'Bad file descriptor');
      return readByteString(buffer);
    });

    expect(read, 'Bad file descriptor');
  });

  test('a wide string is released when the body throws', () {
    expect(
      () => withWideString('x', (_) => throw StateError('boom')),
      throwsStateError,
    );
  });

  test('withWideString accepts non-ASCII', () {
    expect(withWideString('🐄 native.log', readWideString), '🐄 native.log');
  });
}
