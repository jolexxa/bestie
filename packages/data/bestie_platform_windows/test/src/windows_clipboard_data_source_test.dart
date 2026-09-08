import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'mocks.dart';

void main() {
  late MockClipboard clipboard;
  late MockClipboardSession session;
  late WindowsClipboardDataSource dataSource;

  setUp(() {
    clipboard = MockClipboard();
    session = MockClipboardSession();
    dataSource = WindowsClipboardDataSource(clipboard: clipboard);

    when(() => clipboard.open()).thenReturn(ClipboardOpenSucceeded(session));
    when(
      () => session.writeUnicodeText(any()),
    ).thenReturn(const ClipboardWriteSucceeded());
    when(() => session.close()).thenReturn(const ClipboardCloseSucceeded());
  });

  test('writes the text and releases the clipboard', () async {
    await dataSource.copy('cow');

    verifyInOrder([
      () => clipboard.open(),
      () => session.writeUnicodeText('cow'),
      () => session.close(),
    ]);
  });

  test('gives up quietly when another process is holding it', () async {
    when(() => clipboard.open()).thenReturn(const ClipboardOpenFailed(failure));

    await dataSource.copy('cow');

    verifyNever(() => session.writeUnicodeText(any()));
  });

  test('still releases the clipboard when the write is refused', () async {
    when(
      () => session.writeUnicodeText(any()),
    ).thenReturn(const ClipboardWriteFailed(failure));

    await dataSource.copy('cow');

    verify(() => session.close()).called(1);
  });
}
