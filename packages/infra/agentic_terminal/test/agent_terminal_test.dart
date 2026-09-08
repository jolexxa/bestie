import 'dart:async';
import 'dart:convert';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockRunningProcess extends Mock implements RunningProcess {}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  late _MockRunningProcess process;
  late StreamController<List<int>> output;

  setUp(() {
    process = _MockRunningProcess();
    output = StreamController<List<int>>();

    when(() => process.stdout).thenAnswer((_) => output.stream);
    when(() => process.childRepaintsOnResize).thenReturn(false);
    when(() => process.writeBytes(any())).thenReturn(null);
    when(() => process.writeString(any())).thenReturn(null);
    when(
      () => process.resize(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
      ),
    ).thenReturn(null);
    when(
      () => process.kill(force: any(named: 'force')),
    ).thenAnswer((_) async => true);
    when(process.close).thenAnswer((_) async {});
    when(() => process.exit).thenAnswer(
      (_) => Completer<ProcessExit>().future,
    );
    when(() => process.pid).thenAnswer((_) async => 1234);
  });

  tearDown(() async {
    if (!output.isClosed) await output.close();
  });

  AgentTerminal attach({int rows = 24, int cols = 80}) => AgentTerminal.attach(
    process,
    rows: rows,
    cols: cols,
    scrollbackBytes: 0 * 4096,
  );

  group('screenChanges', () {
    test('fires once per chunk applied to the screen', () async {
      final terminal = attach();
      final seen = <void>[];
      final sub = terminal.screenChanges.listen(seen.add);

      output.add(utf8.encode('A'));
      await terminal.waitForText('A', timeout: const Duration(seconds: 1));
      output.add(utf8.encode('B'));
      await terminal.waitForText('AB', timeout: const Duration(seconds: 1));
      // waitForText resolves from inside `parser.advance`, so the signal for
      // that chunk is still queued behind it.
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(2));

      await sub.cancel();
    });

    test('closes with the terminal', () async {
      final terminal = attach();
      var done = false;
      final sub = terminal.screenChanges.listen(
        null,
        onDone: () => done = true,
      );

      await terminal.close();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);

      await sub.cancel();
    });
  });

  group('screen wiring', () {
    test('paints child output onto the screen', () async {
      final terminal = attach();

      output.add(utf8.encode('HELLO'));
      final snapshot = await terminal.waitForText(
        'HELLO',
        timeout: const Duration(seconds: 1),
      );

      expect(snapshot.text, contains('HELLO'));
    });

    test('waitForRegex resolves as soon as the pattern matches', () async {
      final terminal = attach();

      output.add(utf8.encode('code 42'));
      final snapshot = await terminal.waitForRegex(
        RegExp(r'code \d+'),
        timeout: const Duration(seconds: 1),
      );

      expect(snapshot.text, matches(RegExp(r'code \d+')));
    });

    test('waitFor accepts an arbitrary predicate', () async {
      final terminal = attach();

      output.add(utf8.encode('ready'));
      final snapshot = await terminal.waitFor(
        (s) => s.text.contains('ready'),
        timeout: const Duration(seconds: 1),
      );

      expect(snapshot.text, contains('ready'));
    });

    test('snapshot reflects the size it was attached at', () {
      final terminal = attach(rows: 40, cols: 120);

      final snapshot = terminal.snapshot(includeScrollback: true);

      expect(snapshot.rows, 40);
      expect(snapshot.cols, 120);
    });

    test('exposes the live screen model', () {
      expect(attach().screen, isA<Screen>());
    });
  });

  group('input', () {
    test('writeString forwards to the child', () {
      attach().writeString('hi');

      verify(() => process.writeString('hi')).called(1);
    });

    test('writeBytes forwards to the child', () {
      attach().writeBytes(const [1, 2, 3]);

      verify(() => process.writeBytes(const [1, 2, 3])).called(1);
    });

    test('sendKey forwards the key escape sequence', () {
      attach().sendKey(TerminalKey.enter);

      verify(
        () => process.writeString(TerminalKey.enter.sequence),
      ).called(1);
    });

    test('screen replies are routed back to the child stdin', () async {
      attach();

      // DA (Device Attributes) — the screen answers this one itself, so
      // it exercises the outbound path without us calling write.
      output.add(utf8.encode('\x1B[c'));
      await Future<void>.delayed(Duration.zero);

      verify(() => process.writeBytes(any())).called(greaterThan(0));
    });
  });

  group('lifecycle', () {
    test('resize updates both the child tty and the screen grid', () {
      final terminal = attach()..resize(rows: 40, cols: 120);

      verify(() => process.resize(rows: 40, cols: 120)).called(1);
      expect(terminal.snapshot().rows, 40);
      expect(terminal.snapshot().cols, 120);
    });

    test('resize floors a collapsed pane at one cell', () {
      final terminal = attach()..resize(rows: 0, cols: 0);

      verify(() => process.resize(rows: 1, cols: 1)).called(1);
      expect(terminal.snapshot().rows, 1);
      expect(terminal.snapshot().cols, 1);
    });

    test('exit surfaces the child status', () async {
      when(
        () => process.exit,
      ).thenAnswer((_) async => const ProcessExited(7));

      expect(await attach().exit, const ProcessExited(7));
    });

    test('pid surfaces the target pid', () async {
      expect(await attach().pid, 1234);
    });

    test('kill terminates the child immediately', () async {
      await attach().kill();

      verify(() => process.kill(force: true)).called(1);
    });

    test('close stops the child and releases it', () async {
      await attach().close();

      verifyInOrder([
        () => process.kill(force: true),
        process.close,
      ]);
    });

    test(
      'close stops painting, so a late byte cannot touch the screen',
      () async {
        final terminal = attach();
        output.add(utf8.encode('BEFORE'));
        await terminal.waitForText(
          'BEFORE',
          timeout: const Duration(seconds: 1),
        );

        await terminal.close();
        output.add(utf8.encode('AFTER'));
        await Future<void>.delayed(Duration.zero);

        expect(terminal.snapshot().text, isNot(contains('AFTER')));
      },
    );
  });
}
