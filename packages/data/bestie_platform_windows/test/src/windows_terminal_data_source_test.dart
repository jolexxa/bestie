import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'mocks.dart';

void main() {
  late MockStdioRedirect redirect;
  late MockConsoleMode console;
  late MockStdout out;
  late MockStdin input;
  late WindowsTerminalDataSource dataSource;

  setUp(() {
    redirect = MockStdioRedirect();
    console = MockConsoleMode();
    out = MockStdout();
    input = MockStdin();
    dataSource = WindowsTerminalDataSource(
      redirect: redirect,
      console: console,
      stdoutSink: out,
      stdinStream: input,
    );

    when(() => out.hasTerminal).thenReturn(true);
    when(() => input.hasTerminal).thenReturn(true);
    when(() => out.write(any<dynamic>())).thenReturn(null);
    when(
      () => console.clearBits(any(), any()),
    ).thenReturn(const ConsoleModeChangeSucceeded(7));
    when(
      () => console.setBits(any(), any()),
    ).thenReturn(const ConsoleModeChangeSucceeded(3));
    when(
      () => console.restore(any(), any()),
    ).thenReturn(const ConsoleModeRestoreSucceeded());
  });

  group('redirectStderr', () {
    late MockStderrRedirection redirection;
    late MockCrtFd saved;

    setUp(() {
      redirection = MockStderrRedirection();
      saved = MockCrtFd();
      when(() => redirection.savedStderr).thenReturn(saved);
      when(
        () => redirection.revert(),
      ).thenReturn(const StderrRestoreSucceeded());
      when(() => redirect.redirectStderr(any())).thenReturn(
        StderrRedirectSucceeded(redirection),
      );
    });

    test('hands back a sink that still reaches the real terminal', () {
      when(
        () => saved.write(any()),
      ).thenReturn(const CrtWriteSucceeded(5));

      final override = dataSource.redirectStderr(targetPath: r'C:\native.log');

      expect(override, isNotNull);
      verify(() => redirect.redirectStderr(r'C:\native.log')).called(1);
      override!.originalSink!.write('hello');
      verify(() => saved.write(any())).called(1);
    });

    test('restores both layers on revert', () async {
      final override = dataSource.redirectStderr(targetPath: r'C:\native.log');

      await override!.revert();

      verify(() => redirection.revert()).called(1);
    });

    test('reports no override when the redirect fails', () {
      when(
        () => redirect.redirectStderr(any()),
      ).thenReturn(const StderrRedirectFailed(failure));

      expect(dataSource.redirectStderr(targetPath: r'C:\native.log'), isNull);
    });
  });

  group('captureInput', () {
    test('stops the console from eating control keys', () {
      final override = dataSource.captureInput({InputCapture.controlKeys});

      expect(override, isNotNull);
      verify(
        () => console.clearBits(STD_INPUT_HANDLE, ENABLE_PROCESSED_INPUT),
      ).called(1);
    });

    test('covers flow control with the same console bit', () {
      dataSource.captureInput({InputCapture.flowControl});

      verify(
        () => console.clearBits(STD_INPUT_HANDLE, ENABLE_PROCESSED_INPUT),
      ).called(1);
    });

    test('asks once when both groups map to that bit', () {
      dataSource.captureInput({
        InputCapture.controlKeys,
        InputCapture.flowControl,
      });

      verify(
        () => console.clearBits(STD_INPUT_HANDLE, ENABLE_PROCESSED_INPUT),
      ).called(1);
    });

    test('reports no override for editing keys — Windows never ate them', () {
      expect(dataSource.captureInput({InputCapture.editingKeys}), isNull);
      verifyNever(() => console.clearBits(any(), any()));
    });

    test('reports no override when asked for nothing', () {
      expect(dataSource.captureInput(const {}), isNull);
      verifyNever(() => console.clearBits(any(), any()));
    });

    test('reports no override when stdin is not a terminal', () {
      when(() => input.hasTerminal).thenReturn(false);

      expect(dataSource.captureInput({InputCapture.controlKeys}), isNull);
      verifyNever(() => console.clearBits(any(), any()));
    });

    test('reports no override when the mode cannot be changed', () {
      when(
        () => console.clearBits(any(), any()),
      ).thenReturn(const ConsoleModeChangeFailed(failure));

      expect(dataSource.captureInput({InputCapture.controlKeys}), isNull);
    });

    test('puts the mode back exactly as it was on revert', () async {
      final override = dataSource.captureInput({InputCapture.controlKeys});

      await override!.revert();

      expect(override.originalSink, isNull);
      verify(() => console.restore(STD_INPUT_HANDLE, 7)).called(1);
    });
  });

  group('setWindowTitle', () {
    test('pushes the old title and sets the new one', () {
      final override = dataSource.setWindowTitle('cow');

      expect(override, isNotNull);
      verify(() => out.write('\x1b[22;0t\x1b]0;cow\x07')).called(1);
    });

    test('enables virtual terminal processing first, for legacy conhost', () {
      dataSource.setWindowTitle('cow');

      verifyInOrder([
        () => console.setBits(
          STD_OUTPUT_HANDLE,
          ENABLE_VIRTUAL_TERMINAL_PROCESSING,
        ),
        () => out.write(any<dynamic>()),
      ]);
    });

    test('pops the title and puts the output mode back on revert', () async {
      final override = dataSource.setWindowTitle('cow');

      await override!.revert();

      verify(() => out.write('\x1b[23;0t')).called(1);
      verify(() => console.restore(STD_OUTPUT_HANDLE, 3)).called(1);
    });

    test('restores no mode it never changed', () async {
      when(
        () => console.setBits(any(), any()),
      ).thenReturn(const ConsoleModeChangeFailed(failure));

      final override = dataSource.setWindowTitle('cow');
      await override!.revert();

      verify(() => out.write('\x1b[23;0t')).called(1);
      verifyNever(() => console.restore(any(), any()));
    });

    test('reports no override when stdout is not a terminal', () {
      when(() => out.hasTerminal).thenReturn(false);

      expect(dataSource.setWindowTitle('cow'), isNull);
      verifyNever(() => out.write(any<dynamic>()));
    });
  });
}
