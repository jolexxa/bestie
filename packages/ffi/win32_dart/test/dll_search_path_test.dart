import 'dart:ffi';

import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/src/text.dart';
import 'package:win32_dart/win32_dart.dart';

import 'native_stubs.dart';

void main() {
  setUpAll(registerPointerFallbacks);

  late MockWindowsBindings bindings;
  late DllSearchPath searchPath;

  setUp(() {
    bindings = MockWindowsBindings();
    searchPath = DllSearchPath(bindings);
    when(() => bindings.GetLastError()).thenReturn(3);
    whenFormatMessage(bindings, 'The system cannot find the path specified.');
  });

  test('passes the directory through as a wide string', () {
    when(() => bindings.SetDllDirectoryW(any())).thenAnswer((invocation) {
      final path = invocation.positionalArguments[0] as Pointer<WChar>;
      expect(readWideString(path), r'C:\libs');
      return 1;
    });

    expect(searchPath.use(r'C:\libs'), isA<DllSearchPathSucceeded>());
  });

  test('reports a zero return as a failure', () {
    when(() => bindings.SetDllDirectoryW(any())).thenReturn(0);

    final result = searchPath.use(r'C:\nope');

    expect(
      result,
      isA<DllSearchPathFailed>().having(
        (result) => result.failure.function,
        'failure.function',
        'SetDllDirectoryW',
      ),
    );
  });
}
