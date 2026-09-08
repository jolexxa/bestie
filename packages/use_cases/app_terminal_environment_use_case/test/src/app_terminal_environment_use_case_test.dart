import 'dart:io';

import 'package:app_terminal_environment_use_case/app_terminal_environment_use_case.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:test/test.dart';

class _MockPlatformRepository extends Mock implements OSPlatformRepository {}

class _MockTerminalOverride extends Mock implements TerminalOverride {}

class _MockIOSink extends Mock implements IOSink {}

/// A [TerminalOverride] whose [TerminalOverride.revert] is stubbed to succeed.
TerminalOverride stubOverride() {
  final override = _MockTerminalOverride();
  when(override.revert).thenAnswer((_) async {});
  return override;
}

void main() {
  const capturedKeys = {InputCapture.controlKeys, InputCapture.editingKeys};

  late _MockPlatformRepository platform;
  late AppTerminalEnvironmentUseCase useCase;

  setUpAll(() => registerFallbackValue(<InputCapture>{}));

  setUp(() {
    platform = _MockPlatformRepository();
    useCase = AppTerminalEnvironmentUseCase(platformRepository: platform);
  });

  tearDown(() => useCase.dispose());

  void stubActivation({
    TerminalOverride? stderr,
    TerminalOverride? title,
    TerminalOverride? capture,
  }) {
    when(
      () => platform.redirectStderr(targetPath: any(named: 'targetPath')),
    ).thenReturn(stderr);
    when(() => platform.setWindowTitle(any())).thenReturn(title);
    when(() => platform.captureInput(any())).thenReturn(capture);
  }

  group('activate', () {
    test('applies stderr redirect, window title, and input capture', () {
      stubActivation(
        stderr: stubOverride(),
        title: stubOverride(),
        capture: stubOverride(),
      );

      useCase.activate(nativeLogPath: '/logs/native.log', title: 'cow');

      verify(
        () => platform.redirectStderr(targetPath: '/logs/native.log'),
      ).called(1);
      verify(() => platform.setWindowTitle('cow')).called(1);
      verify(() => platform.captureInput(capturedKeys)).called(1);
    });
  });

  group('restore', () {
    test('reverts remembered overrides in reverse order', () async {
      final stderr = stubOverride();
      final title = stubOverride();
      final capture = stubOverride();
      stubActivation(stderr: stderr, title: title, capture: capture);

      useCase.activate(nativeLogPath: '/logs/native.log', title: 'cow');
      await useCase.restore();

      verifyInOrder([
        capture.revert,
        title.revert,
        stderr.revert,
      ]);
    });

    test('skips overrides the platform declined (null)', () async {
      final capture = stubOverride();
      stubActivation(capture: capture);

      useCase.activate(nativeLogPath: '/logs/native.log', title: 'cow');

      await expectLater(useCase.restore(), completes);
      verify(capture.revert).called(1);
    });

    test('a second restore reverts nothing more', () async {
      final capture = stubOverride();
      stubActivation(capture: capture);

      useCase.activate(nativeLogPath: '/logs/native.log', title: 'cow');
      await useCase.restore();
      clearInteractions(capture);

      await useCase.restore();

      verifyNever(capture.revert);
    });
  });

  group('reassertInputCapture', () {
    test('re-applies the captured key groups', () {
      when(() => platform.captureInput(any())).thenReturn(null);

      useCase.reassertInputCapture();

      verify(() => platform.captureInput(capturedKeys)).called(1);
    });
  });

  group('flushThenExit', () {
    test('drains both streams, then exits with the status', () async {
      final out = _MockIOSink();
      final err = _MockIOSink();
      when(out.close).thenAnswer((_) async {});
      when(err.close).thenAnswer((_) async {});
      var exitedWith = -1;
      final useCase = AppTerminalEnvironmentUseCase(
        platformRepository: platform,
        stdoutSink: out,
        stderrSink: err,
        exitProcess: (code) => exitedWith = code,
      );

      await useCase.flushThenExit(2);

      verify(out.close).called(1);
      verify(err.close).called(1);
      expect(exitedWith, 2);
    });
  });

  group('palette commands', () {
    Command commandById(String id) =>
        useCase.commands.firstWhere((command) => command.id == id);

    Future<Availability> firstGate(Command command) async {
      final gates = <Availability>[];
      final sub = command.availability.listen(gates.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      return gates.first;
    }

    test('contributes recapture-input and quit', () {
      expect(
        useCase.commands.map((command) => command.id),
        containsAll(['app.recaptureInput', 'app.quit']),
      );
    });

    test(
      'recapture input is always available and re-asserts capture',
      () async {
        when(() => platform.captureInput(any())).thenReturn(null);
        final command = commandById('app.recaptureInput');
        expect(await firstGate(command), isA<Available>());

        expect(await command.invoke(const Answers.empty()), isA<CommandRan>());
        verify(() => platform.captureInput(capturedKeys)).called(1);
      },
    );

    test('quit command requests exit with 0', () async {
      final command = commandById('app.quit');
      expect(await firstGate(command), isA<Available>());

      final codes = <int>[];
      final sub = useCase.exitRequested.listen(codes.add);
      addTearDown(sub.cancel);

      expect(await command.invoke(const Answers.empty()), isA<CommandRan>());
      await Future<void>.delayed(Duration.zero);
      expect(codes, [0]);
    });
  });

  group('quit', () {
    test('emits the requested exit code on exitRequested', () async {
      final codes = <int>[];
      final sub = useCase.exitRequested.listen(codes.add);
      addTearDown(sub.cancel);

      useCase.quit(3);

      await Future<void>.delayed(Duration.zero);
      expect(codes, [3]);
    });
  });
}
