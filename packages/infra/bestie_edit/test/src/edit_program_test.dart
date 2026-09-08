import 'dart:convert';

import 'package:bestie_edit/bestie_edit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockProcessHost extends Mock implements ProcessHost {}

class _MockRunningProcess extends Mock implements RunningProcess {}

class _FakeSandbox implements Sandbox {}

const _request = ReplaceRequest(
  path: '/work/main.dart',
  oldText: 'hello',
  newText: 'goodbye',
);

const _failure = SpawnFailure(
  function: 'posix_spawnp',
  message: 'No such file or directory',
  code: 2,
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeSandbox()));

  late _MockProcessHost host;
  late _MockRunningProcess process;
  late EditProgram program;

  setUp(() {
    host = _MockProcessHost();
    process = _MockRunningProcess();
    program = EditProgram(
      host: host,
      path: '/opt/bestie/bestie_edit',
      environment: const {'HOME': '/home/cow'},
    );

    when(() => process.stdout).thenAnswer((_) => const Stream.empty());
    when(() => process.stderr).thenAnswer((_) => const Stream.empty());
    when(() => process.exit).thenAnswer((_) async => const ProcessExited(0));
    when(() => process.writeString(any())).thenReturn(null);
    when(process.closeStdin).thenAnswer((_) async {});
    when(process.close).thenAnswer((_) async {});
  });

  void whenSpawned(ProcessSpawnResult result) {
    when(
      () => host.piped(
        executable: any(named: 'executable'),
        environment: any(named: 'environment'),
        sandbox: any(named: 'sandbox'),
      ),
    ).thenReturn(result);
  }

  void whenPrints(String stdout, {String stderr = ''}) {
    when(
      () => process.stdout,
    ).thenAnswer((_) => Stream.value(utf8.encode(stdout)));
    when(
      () => process.stderr,
    ).thenAnswer((_) => Stream.value(utf8.encode(stderr)));
  }

  group('spawning', () {
    setUp(() => whenSpawned(ProcessSpawnSucceeded(process)));

    test('runs the program at its path, in the environment given', () async {
      final sandbox = _FakeSandbox();
      whenPrints('{"outcome":"noChange"}');

      await program.run(_request, sandbox: sandbox);

      verify(
        () => host.piped(
          executable: '/opt/bestie/bestie_edit',
          environment: const {'HOME': '/home/cow'},
          sandbox: sandbox,
        ),
      ).called(1);
    });

    test('writes an edit as json under its action and closes stdin', () async {
      whenPrints('{"outcome":"noChange"}');

      await program.run(_request);

      final written =
          verify(() => process.writeString(captureAny())).captured.single
              as String;
      expect(jsonDecode(written), {
        'action': 'edit',
        'path': '/work/main.dart',
        'old': 'hello',
        'new': 'goodbye',
        'replaceAll': false,
      });
      verifyInOrder([process.closeStdin, process.close]);
    });

    test('writes a create as json under its action', () async {
      whenPrints('{"outcome":"created"}');

      await program.run(
        const CreateRequest(path: '/work/new.dart', contents: 'void main() {}'),
      );

      final written =
          verify(() => process.writeString(captureAny())).captured.single
              as String;
      expect(jsonDecode(written), {
        'action': 'create',
        'path': '/work/new.dart',
        'contents': 'void main() {}',
      });
    });

    test('reports a program that never started', () async {
      whenSpawned(const ProcessSpawnFailed(_failure));

      final run = await program.run(_request);

      expect(run, isA<EditProgramNotStarted>());
      expect((run as EditProgramNotStarted).failure, _failure);
    });
  });

  group('the reply', () {
    setUp(() => whenSpawned(ProcessSpawnSucceeded(process)));

    Future<EditReply> replyTo(String stdout) async {
      whenPrints(stdout);
      return ((await program.run(_request)) as EditAnswered).reply;
    }

    test('reads a created file', () async {
      expect(await replyTo('{"outcome":"created"}'), isA<EditCreated>());
    });

    test('reads a success with its snippet and diff', () async {
      final reply = await replyTo(
        jsonEncode({
          'outcome': 'succeeded',
          'replacements': 2,
          'snippet': '     1\tgoodbye',
          'diff': {
            'hunks': [
              {
                'oldStart': 1,
                'oldCount': 1,
                'newStart': 1,
                'newCount': 1,
                'lines': [
                  {'kind': 'removed', 'text': 'hello'},
                  {'kind': 'added', 'text': 'goodbye'},
                ],
              },
            ],
            'added': 1,
            'removed': 1,
            'truncated': false,
          },
        }),
      );

      final succeeded = reply as EditSucceeded;
      expect(succeeded.replacements, 2);
      expect(succeeded.snippet, '     1\tgoodbye');
      expect(
        succeeded.diff.hunks.single.lines.first.kind,
        DiffLineKind.removed,
      );
      expect(succeeded.diff.added, 1);
    });

    test('reads every refusal by its outcome', () async {
      expect(
        await replyTo('{"outcome":"targetMissing"}'),
        isA<EditTargetMissing>(),
      );
      expect(
        await replyTo('{"outcome":"ambiguous","occurrences":3}'),
        isA<EditAmbiguous>().having((r) => r.occurrences, 'occurrences', 3),
      );
      expect(await replyTo('{"outcome":"noChange"}'), isA<EditNoChange>());
      expect(
        await replyTo('{"outcome":"pathMissing"}'),
        isA<EditPathMissing>(),
      );
      expect(
        await replyTo('{"outcome":"pathExists"}'),
        isA<EditPathExists>(),
      );
      expect(
        await replyTo('{"outcome":"isDirectory"}'),
        isA<EditIsDirectory>(),
      );
      expect(await replyTo('{"outcome":"denied"}'), isA<EditDenied>());
      expect(await replyTo('{"outcome":"notText"}'), isA<EditNotText>());
    });

    test('reports a nonzero exit with what stderr said', () async {
      whenPrints('', stderr: 'bestie_edit: could not parse the request\n');
      when(() => process.exit).thenAnswer((_) async => const ProcessExited(2));

      final run = await program.run(_request);

      expect(
        run,
        isA<EditProgramFailed>()
            .having((r) => r.exit, 'exit', const ProcessExited(2))
            .having((r) => r.stderr, 'stderr', contains('could not parse')),
      );
    });

    test('reports a program that was killed', () async {
      when(
        () => process.exit,
      ).thenAnswer((_) async => const ProcessSignaled(9));

      final run = await program.run(_request);

      expect((run as EditProgramFailed).exit, const ProcessSignaled(9));
    });

    test('reports output that is not a reply', () async {
      whenPrints('Segmentation fault');

      final run = await program.run(_request);

      expect((run as EditProgramGarbled).stdout, 'Segmentation fault');
    });
  });
}
