@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:posix_spawner/posix_spawner.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:test/test.dart';

class _MockSupervisedProcess extends Mock implements PosixSupervisedProcess {}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  late _MockSupervisedProcess supervised;

  setUp(() {
    supervised = _MockSupervisedProcess();
    when(() => supervised.exitStatus).thenAnswer(
      (_) => Completer<PosixSupervisorOutcome>().future,
    );
    when(() => supervised.write(any())).thenReturn(null);
    when(supervised.closeStdin).thenAnswer((_) async {});
    when(supervised.close).thenAnswer((_) async {});
    when(
      () => supervised.resize(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
      ),
    ).thenReturn(null);
  });

  group('exit status', () {
    test('decodes a reported wait status', () async {
      when(
        () => supervised.exitStatus,
      ).thenAnswer(
        (_) async =>
            const PosixSupervisorExited(targetPid: 4321, rawStatus: 42 << 8),
      );

      final process = PosixRunningProcess(supervised);

      expect(await process.exit, const ProcessExited(42));
    });

    test('a lost supervisor is not mistaken for a clean exit', () async {
      when(
        () => supervised.exitStatus,
      ).thenAnswer((_) async => const PosixSupervisorLost());

      final process = PosixRunningProcess(supervised);

      expect(await process.exit, const ProcessSupervisorLost());
    });
  });

  group('stdin', () {
    test('writes bytes through to the child', () {
      PosixRunningProcess(supervised).writeBytes(const [1, 2, 3]);

      verify(() => supervised.write(const [1, 2, 3])).called(1);
    });

    test('encodes strings as UTF-8', () {
      PosixRunningProcess(supervised).writeString('hi 🐮');

      verify(() => supervised.write(utf8.encode('hi 🐮'))).called(1);
    });

    test('rejects writes once stdin is closed', () async {
      final process = PosixRunningProcess(supervised);
      await process.closeStdin();

      expect(() => process.writeBytes(const [1]), throwsStateError);
      expect(() => process.writeString('x'), throwsStateError);
      verifyNever(() => supervised.write(any()));
    });
  });

  group('kill', () {
    test('asks politely by default, so the child can clean up', () async {
      when(() => supervised.kill(any())).thenAnswer((_) async => true);

      await PosixRunningProcess(supervised).kill();

      // Asserting the exact signal is the point, even though SIGTERM
      // happens to be posix_dart's default.
      // ignore: avoid_redundant_argument_values
      verify(() => supervised.kill(15)).called(1);
    });

    test('forces termination when asked to', () async {
      when(() => supervised.kill(any())).thenAnswer((_) async => true);

      await PosixRunningProcess(supervised).kill(force: true);

      verify(() => supervised.kill(9)).called(1);
    });

    test('reports false when there was no live target', () async {
      when(() => supervised.kill(any())).thenAnswer((_) async => false);

      expect(await PosixRunningProcess(supervised).kill(), isFalse);
    });
  });

  group('host resize forwarding', () {
    test('leaves the grid to the child, which only gets SIGWINCH', () {
      expect(PosixRunningProcess(supervised).childRepaintsOnResize, isFalse);
    });

    test('is off unless a resize stream is supplied', () async {
      PosixRunningProcess(supervised);
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => supervised.resize(
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
        ),
      );
    });

    test('pushes host size changes down to the child tty', () async {
      final host = StreamController<Winsize>();
      PosixRunningProcess(supervised, hostResizeStream: host.stream);

      host.add((rows: 40, cols: 120));
      await Future<void>.delayed(Duration.zero);

      verify(() => supervised.resize(rows: 40, cols: 120)).called(1);
      await host.close();
    });

    test(
      'stops forwarding after close, so a closed pty is never poked',
      () async {
        final host = StreamController<Winsize>();
        final process = PosixRunningProcess(
          supervised,
          hostResizeStream: host.stream,
        );

        await process.close();
        host.add((rows: 40, cols: 120));
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => supervised.resize(
            rows: any(named: 'rows'),
            cols: any(named: 'cols'),
          ),
        );
        await host.close();
      },
    );
  });

  group('lifecycle', () {
    test('close releases the underlying process', () async {
      await PosixRunningProcess(supervised).close();

      verify(supervised.close).called(1);
    });

    test('exposes the target pid and output streams', () async {
      when(() => supervised.pid).thenAnswer((_) async => 4321);
      when(() => supervised.stdout).thenAnswer((_) => const Stream.empty());
      when(() => supervised.stderr).thenAnswer((_) => const Stream.empty());

      final process = PosixRunningProcess(supervised);

      expect(await process.pid, 4321);
      expect(await process.stdout.toList(), isEmpty);
      expect(await process.stderr.toList(), isEmpty);
    });
  });
}
