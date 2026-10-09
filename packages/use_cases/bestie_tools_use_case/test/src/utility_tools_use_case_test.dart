import 'dart:async';

import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:config_repository/config_repository.dart';
import 'package:config_repository/testing.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockToolWorkerPool extends Mock implements ToolWorkerPool {}

class _MockSandboxRepository extends Mock implements SandboxRepository {}

class _MockWorkspacePaths extends Mock implements WorkspacePaths {}

class _FakeSandbox implements Sandbox {}

const _keyId = 'tools.concurrent';

ToolsConfigKeys _configKeys() => ToolsConfigKeys(
  concurrentTools: ConfigKey<int>(
    id: _keyId,
    path: const [_keyId],
    codec: ConfigCodecs.integers,
    defaultValue: () => defaultConcurrentTools,
  ),
  toolCacheChars: ConfigKey<int>(
    id: 'tools.cache_characters',
    path: const ['tools.cache_characters'],
    codec: ConfigCodecs.integers,
    defaultValue: () => defaultToolCacheChars,
  ),
);

ToolCallInvocation _invocation(
  String toolName, {
  Map<String, Object?> arguments = const {},
}) => ToolCallInvocation(
  conversationId: 'conversation',
  agentId: 'agent',
  callId: 'call-1',
  toolName: toolName,
  outputPath: 'output',
  maxOutputChars: 4000,
  arguments: arguments,
);

/// What the pool was handed for the one call it queued.
final class _Queued {
  _Queued(List<dynamic> captured)
    : start = captured[0] as Future<ToolWorkStart>,
      lane = captured[1] as String?;

  final Future<ToolWorkStart> start;
  final String? lane;

  /// The request the call was prepared into.
  Future<ToolWorkRequest> get request async =>
      (await start as ToolWorkReady).request;
}

_Queued _queued(_MockToolWorkerPool pool) => _Queued(
  verify(
    () => pool.run(captureAny(), lane: captureAny(named: 'lane')),
  ).captured,
);

void main() {
  late _MockToolWorkerPool pool;
  late _MockSandboxRepository sandboxes;
  late _MockWorkspacePaths workspacePaths;
  late FakeConfigRepository config;

  UtilityToolsUseCase useCaseWith() => UtilityToolsUseCase(
    pool: pool,
    config: config,
    configKeys: _configKeys(),
    sandboxes: sandboxes,
    workspacePaths: workspacePaths,
  );

  setUpAll(() {
    registerFallbackValue(
      Future<ToolWorkStart>.value(
        ToolWorkReady(ToolWorkRequest(_invocation('edit'))),
      ),
    );
  });

  setUp(() {
    pool = _MockToolWorkerPool();
    sandboxes = _MockSandboxRepository();
    workspacePaths = _MockWorkspacePaths();
    when(() => workspacePaths.targetOf(any())).thenReturn('/work/a.md');
    config = FakeConfigRepository();
    when(() => pool.close()).thenAnswer((_) async {});
    when(
      () => pool.run(any(), lane: any(named: 'lane')),
    ).thenReturn(Job.done('done'));
    when(
      () => sandboxes.confine(),
    ).thenAnswer((_) async => const Unconfined());
  });

  group('definitions', () {
    test('offers every utility tool, the file tools first', () {
      final names = useCaseWith().definitions.definitions
          .map((definition) => definition.name)
          .toList();

      expect(names, [
        'create',
        'edit',
        'web_search',
        'news_search',
        'web_fetch',
        'wiki_search',
        'arxiv_search',
        'calculator',
        'date_time',
      ]);
    });
  });

  group('respond', () {
    test(
      'hands a tool it offers to the pool, unconfined, in no lane',
      () async {
        final invocation = _invocation('web_search');

        await useCaseWith().respond(invocation);

        final queued = _queued(pool);
        final request = await queued.request;
        expect(request.invocation, invocation);
        expect(request.sandbox, isNull);
        expect(queued.lane, isNull);
        verifyNever(() => sandboxes.confine());
      },
    );

    test('queues a write before the sandbox has answered', () async {
      final confining = Completer<ConfinementDecision>();
      when(() => sandboxes.confine()).thenAnswer((_) => confining.future);
      final sandbox = _FakeSandbox();

      await useCaseWith().respond(
        _invocation('edit', arguments: {'path': 'a.md'}),
      );

      final queued = _queued(pool);
      confining.complete(Confined(sandbox));
      expect((await queued.request).sandbox, sandbox);
    });

    test('sends an edit with the sandbox it was confined to', () async {
      final sandbox = _FakeSandbox();
      when(
        () => sandboxes.confine(),
      ).thenAnswer((_) async => Confined(sandbox));

      await useCaseWith().respond(_invocation('edit'));

      expect((await _queued(pool).request).sandbox, sandbox);
    });

    test('confines a create the same way', () async {
      final sandbox = _FakeSandbox();
      when(
        () => sandboxes.confine(),
      ).thenAnswer((_) async => Confined(sandbox));

      await useCaseWith().respond(_invocation('create'));

      expect((await _queued(pool).request).sandbox, sandbox);
    });

    test('sends an edit unconfined when the sandbox says so', () async {
      await useCaseWith().respond(_invocation('edit'));

      expect((await _queued(pool).request).sandbox, isNull);
      verify(() => sandboxes.confine()).called(1);
    });

    for (final toolName in ['create', 'edit']) {
      test('refuses a $toolName the sandbox would not confine', () async {
        when(
          () => sandboxes.confine(),
        ).thenAnswer((_) async => const ConfinementRefused('no seatbelt'));

        await useCaseWith().respond(_invocation(toolName));

        final start = await _queued(pool).start;
        expect(
          (start as ToolWorkRefused).message,
          'Could not confine the editor: no seatbelt',
        );
      });
    }

    group('the file a write names', () {
      test('is where it really lands, and the lane it queues in', () async {
        when(() => workspacePaths.targetOf('link.md')).thenReturn('/real.md');

        await useCaseWith().respond(
          _invocation(
            'edit',
            arguments: {
              'path': 'link.md',
              'old_string': 'x',
              'new_string': 'y',
            },
          ),
        );

        final queued = _queued(pool);
        final request = await queued.request;
        expect(queued.lane, '/real.md');
        expect(request.invocation.arguments, {
          'path': '/real.md',
          'old_string': 'x',
          'new_string': 'y',
        });
        expect(request.invocation.callId, 'call-1');
        expect(request.invocation.toolName, 'edit');
        expect(request.invocation.outputPath, 'output');
        expect(request.invocation.maxOutputChars, 4000);
      });

      for (final arguments in <Map<String, Object?>>[
        {},
        {'path': ''},
        {'path': 7},
      ]) {
        test('is left as $arguments for the tool to reject', () async {
          final invocation = _invocation('create', arguments: arguments);

          await useCaseWith().respond(invocation);

          final queued = _queued(pool);
          expect(queued.lane, isNull);
          expect((await queued.request).invocation, invocation);
          verifyNever(() => workspacePaths.targetOf(any()));
        });
      }

      test('is never looked up for a tool that does not write', () async {
        await useCaseWith().respond(
          _invocation('web_fetch', arguments: {'path': 'a.md'}),
        );

        verifyNever(() => workspacePaths.targetOf(any()));
      });
    });

    test('answers a tool it does not offer without taking a slot', () async {
      final job = await useCaseWith().respond(_invocation('missing'));

      expect(
        (await job.settled as JobFailed).message,
        contains('No such tool: missing'),
      );
      verifyNever(() => pool.run(any(), lane: any(named: 'lane')));
    });
  });

  group('concurrency', () {
    test('sizes the pool from configuration on construction', () {
      config[_keyId] = 6;

      useCaseWith();

      verify(() => pool.size = 6).called(1);
    });

    test('falls back to the default when nothing is configured', () {
      useCaseWith();

      verify(() => pool.size = defaultConcurrentTools).called(1);
    });

    test('resizes the pool when the setting changes', () async {
      useCaseWith();

      config[_keyId] = 2;
      await Future<void>.delayed(Duration.zero);

      verify(() => pool.size = 2).called(1);
    });

    test('holds a hand-edited value to the range the pool trusts', () {
      config[_keyId] = maxConcurrentTools + 100;

      useCaseWith();

      verify(() => pool.size = maxConcurrentTools).called(1);
    });

    test('holds a hand-edited value above zero', () {
      config[_keyId] = 0;

      useCaseWith();

      verify(() => pool.size = minConcurrentTools).called(1);
    });
  });

  group('dispose', () {
    test('closes the pool and stops following configuration', () async {
      final useCase = useCaseWith();

      await useCase.dispose();
      config[_keyId] = 3;
      await Future<void>.delayed(Duration.zero);

      verify(() => pool.close()).called(1);
      verifyNever(() => pool.size = 3);
    });
  });
}
