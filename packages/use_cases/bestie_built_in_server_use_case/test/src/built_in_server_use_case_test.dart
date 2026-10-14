import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_built_in_server_use_case/bestie_built_in_server_use_case.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:config_repository/testing.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_local/provider_local.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderModelRef;
import 'package:provider_repository/provider_repository.dart';
import 'package:test/test.dart';

final class _MockServerRepository extends Mock
    implements BuiltInServerRepository {}

final class _MockProviderRepository extends Mock
    implements ProviderRepository {}

final class _MockAgentRepository extends Mock implements AgentRepository {}

final class _MockAgentSession extends Mock implements AgentSession {}

const _localModel = ProviderSettings(
  model: ProviderModelRef(providerId: 'local', modelId: 'qwen3-8b'),
  maxAgents: 3,
);

const _hostedModel = ProviderSettings(
  model: ProviderModelRef(providerId: 'openrouter', modelId: 'org/model'),
  maxAgents: 3,
);

final class _Harness {
  _Harness({Map<String, Object?> values = const {}}) {
    config = FakeConfigRepository(values);
    when(() => server.status).thenAnswer((_) => serverStatus);
    when(
      () => server.statusStream,
    ).thenAnswer((_) => serverChanges.stream);
    when(() => server.configure(any())).thenReturn(null);
    when(server.start).thenAnswer((_) async {});
    when(server.stop).thenAnswer((_) async {});
    when(server.restart).thenAnswer((_) async {});
    when(() => providers.settings).thenAnswer((_) => settings);
    when(providers.stop).thenReturn(null);
    when(providers.reconnect).thenReturn(null);
    when(() => agents.primary).thenReturn(primary);
    when(
      () => agents.primaryConversationStream,
    ).thenAnswer((_) => conversationChanges.stream);
    when(() => primary.conversationPhase).thenAnswer((_) => phase);
    useCase = BuiltInServerUseCase(
      config: config,
      configKeys: BuiltInServerConfigKeys.defaults(),
      server: server,
      providers: providers,
      agents: agents,
      providerId: 'local',
    );
  }

  final server = _MockServerRepository();
  final providers = _MockProviderRepository();
  final agents = _MockAgentRepository();
  final primary = _MockAgentSession();
  final serverChanges = StreamController<BuiltInServerStatus>.broadcast();
  final conversationChanges = StreamController<ConversationState>.broadcast();
  late final FakeConfigRepository config;
  late final BuiltInServerUseCase useCase;
  BuiltInServerStatus serverStatus = const ServerOffline();
  ProviderSettings? settings;
  ConversationPhase phase = ConversationPhase.idle;

  void report(BuiltInServerStatus status) {
    serverStatus = status;
    serverChanges.add(status);
  }

  void beginTurn() {
    phase = ConversationPhase.turnInFlight;
    conversationChanges.add(
      const TurnInProgress(
        timelineItems: [],
        conversationPhase: ConversationPhase.turnInFlight,
        activity: TurnActivity.thinking,
      ),
    );
  }

  Command command(String id) =>
      useCase.commands.singleWhere((command) => command.id == id);

  CommandFlow flow(String id) => command(id).body as CommandFlow;

  Future<CommandResult> invoke(String id) =>
      flow(id).invoke(const Answers.empty());

  List<ModelLoadOptions> get configured => verify(
    () => server.configure(captureAny()),
  ).captured.cast<ModelLoadOptions>();
}

void main() {
  setUpAll(() => registerFallbackValue(ModelLoadOptions.defaults));

  group('BuiltInServerConfigKeys', () {
    final keys = BuiltInServerConfigKeys.defaults();

    test('keeps the cap where it was stored, uncapped by default', () {
      expect(keys.contextCap.id, 'provider.local.context_cap');
      expect(keys.contextCap.path, ['provider', 'local', 'contextCap']);
      expect(keys.contextCap.defaultValue(), 0);
      expect(keys.contextCap.field.label, 'Context cap');
      expect(keys.contextCap.field.secret, isFalse);
      expect(keys.optionsKeys, [keys.contextCap]);
    });
  });

  group('BuiltInServerUseCase', () {
    test('configures the server from config, then starts it', () {
      final harness = _Harness(values: {'provider.local.context_cap': 8192});

      verifyInOrder([
        () => harness.server.configure(
          const ModelLoadOptions(contextCap: 8192),
        ),
        harness.server.start,
      ]);
      expect(harness.useCase.options.contextCap, 8192);
    });

    test('leaves the context uncapped when the cap is zero', () {
      final harness = _Harness();

      expect(harness.useCase.options, ModelLoadOptions.defaults);
    });

    test('reconfigures when the cap changes', () async {
      final harness = _Harness();
      harness.config['provider.local.context_cap'] = 4096;
      await pumpEventQueue();

      expect(harness.configured, [
        ModelLoadOptions.defaults,
        const ModelLoadOptions(contextCap: 4096),
      ]);
    });

    test('ignores other keys', () async {
      final harness = _Harness();
      harness.config['app.theme'] = 'dark';
      await pumpEventQueue();

      expect(harness.configured, hasLength(1));
    });

    test('contributes the server group', () {
      final harness = _Harness();
      const stop =
          '⏻ Stop built-in server · Unload the model, free its memory and '
          'stop the server';
      const restart =
          '↻ Restart built-in server · Start the server afresh and load the '
          'model again';

      expect(
        harness.useCase.commands.map(
          (command) =>
              '${command.glyph} ${command.title} · ${command.description}',
        ),
        [stop, restart],
      );
      expect(
        harness.useCase.commands.map((command) => command.group).toSet(),
        {BuiltInServerUseCase.group},
      );
      expect(BuiltInServerUseCase.group, 'Built-in server');
      expect(
        harness.flow('server.stop').running,
        'Stopping the built-in server…',
      );
      expect(
        harness.flow('server.restart').running,
        'Restarting the built-in server…',
      );
      expect(harness.flow('server.stop').next(const Answers.empty()), isNull);
    });

    group('stop', () {
      test('follows the server and the primary turn', () async {
        final harness = _Harness();
        final availability = <Availability>[];
        final subscription = harness
            .command('server.stop')
            .availability
            .listen(availability.add);
        await pumpEventQueue();
        expect(
          (availability.last as Unavailable).reason,
          'built-in server is not running',
        );

        harness.report(const ServerIdle());
        await pumpEventQueue();
        expect(availability.last, isA<Available>());

        harness.beginTurn();
        await pumpEventQueue();
        expect((availability.last as Unavailable).reason, 'turn in progress');
        await subscription.cancel();
      });

      test('is unavailable while the server cannot be held', () async {
        final harness = _Harness();
        for (final status in const [
          ServerTaken(ownerPid: 12),
          ServerIncompatible(protocolVersion: 2, serverVersion: '1.0'),
          ServerFailed(reason: 'no binary'),
        ]) {
          harness.serverStatus = status;
          expect(
            await harness.invoke('server.stop'),
            isA<CommandRejected>().having(
              (rejected) => rejected.reason,
              'reason',
              'built-in server is not running',
            ),
          );
        }
        verifyNever(harness.server.stop);
      });

      test("stops the app's model first when it runs here", () async {
        final harness = _Harness()
          ..serverStatus = const ServerIdle()
          ..settings = _localModel;

        expect(await harness.invoke('server.stop'), isA<CommandRan>());

        verifyInOrder([harness.providers.stop, harness.server.stop]);
      });

      test("leaves the app's model be when it runs elsewhere", () async {
        final harness = _Harness()
          ..serverStatus = const ServerStarting()
          ..settings = _hostedModel;

        expect(await harness.invoke('server.stop'), isA<CommandRan>());

        verifyNever(harness.providers.stop);
        verify(harness.server.stop).called(1);
      });

      test('refuses under a running turn', () async {
        final harness = _Harness()
          ..serverStatus = const ServerIdle()
          ..phase = ConversationPhase.turnInFlight;

        expect(
          await harness.invoke('server.stop'),
          isA<CommandRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            'turn in progress',
          ),
        );
        verifyNever(harness.server.stop);
      });

      test('reports the server at a drawable pace', () {
        fakeAsync((async) {
          final harness = _Harness();
          final statuses = <String?>[];
          harness
              .command('server.stop')
              .status
              .listen(
                (status) => statuses.add(
                  status?.spans.map((span) => span.text).join(),
                ),
              );
          async.flushMicrotasks();

          harness.report(const ServerTaken(ownerPid: 4121));
          async.flushMicrotasks();
          expect(statuses.last, '⚠ in use elsewhere');

          async.elapse(BuiltInServerUseCase.statusInterval);
          for (final progress in [.1, .2, .3]) {
            harness.report(
              ServerLoading(localId: 'qwen3-8b', progress: progress),
            );
          }
          async.flushMicrotasks();
          expect(statuses.last, '◑ loading qwen3-8b 10%');
          async.elapse(BuiltInServerUseCase.statusInterval);
          expect(statuses.last, '◑ loading qwen3-8b 30%');
          expect(statuses, isNot(contains('◑ loading qwen3-8b 20%')));
        });
      });
    });

    group('restart', () {
      test('waits for the primary turn', () async {
        final harness = _Harness();
        final availability = <Availability>[];
        final subscription = harness
            .command('server.restart')
            .availability
            .listen(availability.add);
        await pumpEventQueue();
        expect(availability.last, isA<Available>());

        harness.beginTurn();
        await pumpEventQueue();
        expect((availability.last as Unavailable).reason, 'turn in progress');
        expect(
          await harness.invoke('server.restart'),
          isA<CommandRejected>().having(
            (rejected) => rejected.reason,
            'reason',
            'turn in progress',
          ),
        );
        verifyNever(harness.server.restart);
        await subscription.cancel();
      });

      test("stops the app's model, restarts, then loads it again", () async {
        final harness = _Harness()..settings = _localModel;

        expect(await harness.invoke('server.restart'), isA<CommandRan>());

        verifyInOrder([
          harness.providers.stop,
          harness.server.restart,
          harness.providers.reconnect,
        ]);
      });

      test("leaves the app's model be when it runs elsewhere", () async {
        final harness = _Harness()..settings = _hostedModel;

        expect(await harness.invoke('server.restart'), isA<CommandRan>());

        verify(harness.server.restart).called(1);
        verifyNever(harness.providers.stop);
        verifyNever(harness.providers.reconnect);
      });
    });

    test('dispose stops following config', () async {
      final harness = _Harness();

      await harness.useCase.dispose();
      harness.config['provider.local.context_cap'] = 4096;
      await pumpEventQueue();

      expect(harness.configured, hasLength(1));
    });
  });
}
