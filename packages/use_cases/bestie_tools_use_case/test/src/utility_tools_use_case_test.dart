import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:config_repository/config_repository.dart';
import 'package:config_repository/testing.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockToolWorkerPool extends Mock implements ToolWorkerPool {}

class _MockSandboxRepository extends Mock implements SandboxRepository {}

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

ToolCallInvocation _invocation(String toolName) => ToolCallInvocation(
  conversationId: 'conversation',
  agentId: 'agent',
  callId: 'call-1',
  toolName: toolName,
  outputPath: 'output',
  maxOutputChars: 4000,
  arguments: const {},
);

/// The request the pool received, however it was wrapped.
ToolWorkRequest _sent(_MockToolWorkerPool pool) =>
    verify(() => pool.run(captureAny())).captured.single as ToolWorkRequest;

void main() {
  late _MockToolWorkerPool pool;
  late _MockSandboxRepository sandboxes;
  late FakeConfigRepository config;

  UtilityToolsUseCase useCaseWith() => UtilityToolsUseCase(
    pool: pool,
    config: config,
    configKeys: _configKeys(),
    sandboxes: sandboxes,
  );

  setUpAll(() {
    registerFallbackValue(ToolWorkRequest(_invocation('edit')));
  });

  setUp(() {
    pool = _MockToolWorkerPool();
    sandboxes = _MockSandboxRepository();
    config = FakeConfigRepository();
    when(() => pool.close()).thenAnswer((_) async {});
    when(() => pool.run(any())).thenReturn(Job.done('done'));
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
    test('hands a tool it offers to the pool, unconfined', () async {
      final invocation = _invocation('web_search');

      await useCaseWith().respond(invocation);

      final sent = _sent(pool);
      expect(sent.invocation, invocation);
      expect(sent.sandbox, isNull);
      verifyNever(() => sandboxes.confine());
    });

    test('sends an edit with the sandbox it was confined to', () async {
      final sandbox = _FakeSandbox();
      when(
        () => sandboxes.confine(),
      ).thenAnswer((_) async => Confined(sandbox));
      final invocation = _invocation('edit');

      await useCaseWith().respond(invocation);

      final sent = _sent(pool);
      expect(sent.invocation, invocation);
      expect(sent.sandbox, sandbox);
    });

    test('confines a create the same way', () async {
      final sandbox = _FakeSandbox();
      when(
        () => sandboxes.confine(),
      ).thenAnswer((_) async => Confined(sandbox));
      final invocation = _invocation('create');

      await useCaseWith().respond(invocation);

      final sent = _sent(pool);
      expect(sent.invocation, invocation);
      expect(sent.sandbox, sandbox);
    });

    test('fails a create the sandbox refused', () async {
      when(
        () => sandboxes.confine(),
      ).thenAnswer((_) async => const ConfinementRefused('no seatbelt'));

      final job = await useCaseWith().respond(_invocation('create'));

      expect(
        (await job.settled as JobFailed).message,
        'Could not confine the editor: no seatbelt',
      );
      verifyNever(() => pool.run(any()));
    });

    test('sends an edit unconfined when the sandbox says so', () async {
      await useCaseWith().respond(_invocation('edit'));

      expect(_sent(pool).sandbox, isNull);
      verify(() => sandboxes.confine()).called(1);
    });

    test('fails an edit the sandbox refused without taking a slot', () async {
      when(
        () => sandboxes.confine(),
      ).thenAnswer((_) async => const ConfinementRefused('no seatbelt'));

      final job = await useCaseWith().respond(_invocation('edit'));

      expect(
        (await job.settled as JobFailed).message,
        'Could not confine the editor: no seatbelt',
      );
      verifyNever(() => pool.run(any()));
    });

    test('answers a tool it does not offer without taking a slot', () async {
      final job = await useCaseWith().respond(_invocation('missing'));

      expect(
        (await job.settled as JobFailed).message,
        contains('No such tool: missing'),
      );
      verifyNever(() => pool.run(any()));
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
