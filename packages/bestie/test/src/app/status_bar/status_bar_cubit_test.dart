import 'dart:async';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:bestie/src/app/status_bar/status_bar.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';

class _MockProviderUseCase extends Mock implements ProviderUseCase {}

class _MockChatUseCase extends Mock implements ChatUseCase {}

class _MockSandboxUseCase extends Mock implements SandboxUseCase {}

class _MockAgentProvider extends Mock implements AgentProvider {}

const _modelRef = ProviderModelRef(providerId: 'openrouter', modelId: 'x/y');

final _ready = ProviderStatusReady(
  model: const ResolvedModel(
    ref: _modelRef,
    name: 'Why',
    contextWindow: 1024,
    supportsTools: true,
  ),
  handle: _MockAgentProvider(),
  keyInfo: null,
  providerName: 'OpenRouter',
);

const _idle = ConversationIdle(
  timelineItems: [],
  conversationPhase: ConversationPhase.idle,
);

const _inFlight = TurnInProgress(
  timelineItems: [],
  conversationPhase: ConversationPhase.turnInFlight,
  activity: TurnActivity.thinking,
);

const _fetched = CreditsFetched(
  ProviderCredits(spent: 4, remaining: 6, window: SpendWindow.lifetime),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('StatusBarCubit', () {
    late _MockProviderUseCase providers;
    late _MockChatUseCase chat;
    late _MockSandboxUseCase sandboxes;
    late StreamController<ProviderStatus> statuses;
    late StreamController<CreditsResult> credits;
    late StreamController<ConversationState> conversations;
    late StreamController<SandboxReadiness> readiness;
    late StreamController<WriteGrantsForgotten> forgotten;
    late ConversationState primary;

    setUp(() {
      providers = _MockProviderUseCase();
      chat = _MockChatUseCase();
      sandboxes = _MockSandboxUseCase();
      statuses = StreamController<ProviderStatus>.broadcast();
      credits = StreamController<CreditsResult>.broadcast();
      conversations = StreamController<ConversationState>.broadcast();
      readiness = StreamController<SandboxReadiness>.broadcast();
      forgotten = StreamController<WriteGrantsForgotten>.broadcast();
      primary = _idle;
      when(
        () => sandboxes.writeGrantsForgotten,
      ).thenAnswer((_) => forgotten.stream);
      when(() => sandboxes.readiness).thenReturn(const SandboxReady());
      when(
        () => sandboxes.readinessStream,
      ).thenAnswer((_) => readiness.stream);
      when(() => providers.statusStream).thenAnswer((_) => statuses.stream);
      when(() => providers.creditsStream).thenAnswer((_) => credits.stream);
      when(
        () => providers.status,
      ).thenReturn(const ProviderStatusUnconfigured());
      when(() => providers.lastCredits).thenReturn(null);
      when(providers.refreshCredits).thenAnswer((_) async => _fetched);
      when(
        () => chat.conversationStream,
      ).thenAnswer((_) => conversations.stream);
      when(() => chat.conversationState).thenAnswer((_) => primary);
    });

    tearDown(() async {
      await statuses.close();
      await credits.close();
      await conversations.close();
      await readiness.close();
      await forgotten.close();
    });

    StatusBarCubit build() =>
        StatusBarCubit(providers: providers, chat: chat, sandboxes: sandboxes);

    test('opens on the provider status and the last known balance', () async {
      when(() => providers.status).thenReturn(_ready);
      when(() => providers.lastCredits).thenReturn(_fetched);
      final cubit = build();
      expect(cubit.state.status, _ready);
      expect(cubit.state.credits, _fetched);
      await cubit.close();
    });

    test('asks for a balance once the provider is ready', () async {
      final cubit = build();
      verifyNever(providers.refreshCredits);

      statuses.add(_ready);
      await _settle();
      verify(providers.refreshCredits).called(1);
      expect(cubit.state.status, _ready);

      // Staying ready is not a reason to ask again.
      statuses.add(_ready);
      await _settle();
      verifyNever(providers.refreshCredits);
      await cubit.close();
    });

    test('asks again when the provider was ready from the start', () async {
      when(() => providers.status).thenReturn(_ready);
      final cubit = build();
      verify(providers.refreshCredits).called(1);
      await cubit.close();
    });

    test('mirrors balances as they arrive', () async {
      final cubit = build();
      credits.add(_fetched);
      await _settle();
      expect(cubit.state.credits, _fetched);

      credits.add(const CreditsUnsupported());
      await _settle();
      expect(cubit.state.credits, isA<CreditsUnsupported>());
      await cubit.close();
    });

    test(
      'asks for a balance when a turn finishes, not while it runs',
      () async {
        final cubit = build();
        primary = _inFlight;
        conversations.add(primary);
        await _settle();
        verifyNever(providers.refreshCredits);

        conversations.add(primary);
        await _settle();
        verifyNever(providers.refreshCredits);

        primary = _idle;
        conversations.add(primary);
        await _settle();
        verify(providers.refreshCredits).called(1);

        // Idle ticks without a turn in between stay quiet.
        conversations.add(primary);
        await _settle();
        verifyNever(providers.refreshCredits);
        await cubit.close();
      },
    );

    test('opens on where the sandbox stands', () async {
      when(() => sandboxes.readiness).thenReturn(const SandboxPreparingHost());
      final cubit = build();
      expect(cubit.state.sandbox, isA<SandboxPreparingHost>());
      await cubit.close();
    });

    test(
      'follows the sandbox and announces it once when it comes up',
      () async {
        when(
          () => sandboxes.readiness,
        ).thenReturn(const SandboxPreparingHost());
        final cubit = build();
        final announcements = <SandboxBecameReady>[];
        final sub = cubit.outputsOf<SandboxBecameReady>().listen(
          announcements.add,
        );

        readiness.add(const SandboxProvisioning());
        await _settle();
        expect(cubit.state.sandbox, isA<SandboxProvisioning>());
        expect(announcements, isEmpty);

        readiness.add(const SandboxReady());
        await _settle();
        expect(cubit.state.sandbox, isA<SandboxReady>());
        expect(announcements, hasLength(1));

        // Staying ready is not news.
        readiness.add(const SandboxReady());
        await _settle();
        expect(announcements, hasLength(1));
        await sub.cancel();
        await cubit.close();
      },
    );

    test('a sandbox that was ready from the start is not announced', () async {
      final cubit = build();
      final announcements = <SandboxBecameReady>[];
      final sub = cubit.outputsOf<SandboxBecameReady>().listen(
        announcements.add,
      );

      readiness.add(const SandboxReady());
      await _settle();
      expect(announcements, isEmpty);
      await sub.cancel();
      await cubit.close();
    });

    test('announces how many write grants the sandbox let go of', () async {
      final cubit = build();
      final announcements = <int>[];
      final sub = cubit
          .outputsOf<SandboxForgotWriteGrants>()
          .map((output) => output.count)
          .listen(announcements.add);

      forgotten
        ..add(const WriteGrantsForgotten(directories: ['/a', '/b']))
        ..add(const WriteGrantsForgotten(directories: []));
      await _settle();

      expect(announcements, [2, 0]);
      await sub.cancel();
      await cubit.close();
    });

    test('stops listening when closed', () async {
      final cubit = build();
      await cubit.close();
      expect(statuses.hasListener, isFalse);
      expect(credits.hasListener, isFalse);
      expect(conversations.hasListener, isFalse);
      expect(readiness.hasListener, isFalse);
      expect(forgotten.hasListener, isFalse);
    });
  });

  group('readings', () {
    test('credits read as spend and balance only when fetched', () {
      expect(creditsReading(_fetched), r'$4.00 lifetime · $6.00 left');
      expect(
        creditsReading(
          const CreditsFetched(
            ProviderCredits(spent: 3.25, window: SpendWindow.monthToDate),
          ),
        ),
        r'$3.25 this month',
      );
      expect(creditsReading(null), '');
      expect(creditsReading(const CreditsUnsupported()), '');
      expect(
        creditsReading(
          const CreditsFailed(
            ProviderFailure(kind: InferenceFailureKind.network, message: 'x'),
          ),
        ),
        '',
      );
    });

    test('the provider reads by name and model, or by where it stands', () {
      expect(providerReading(_ready), 'OpenRouter · Why');
      expect(
        providerReading(const ProviderStatusUnconfigured()),
        'no provider configured',
      );
      expect(
        providerReading(const ProviderStatusConnecting(model: _modelRef)),
        'connecting to openrouter:x/y…',
      );
      expect(
        providerReading(
          const ProviderStatusFailed(
            model: _modelRef,
            failure: ProviderFailure(
              kind: InferenceFailureKind.network,
              message: 'nope',
            ),
          ),
        ),
        'openrouter:x/y · nope',
      );
    });

    test('forgetting write grants reads by how many there were', () {
      expect(
        writeGrantsForgottenReading(0),
        'No granted write directories to forget',
      );
      expect(
        writeGrantsForgottenReading(1),
        'Forgot 1 granted write directory',
      );
      expect(
        writeGrantsForgottenReading(3),
        'Forgot 3 granted write directories',
      );
    });

    test('the sandbox reads as what it is busy with, or nothing', () {
      expect(sandboxReading(const SandboxPreparingHost()), 'preparing sandbox');
      expect(
        sandboxReading(const SandboxProvisioning()),
        'provisioning sandbox',
      );
      expect(sandboxReading(const SandboxReady()), isNull);
    });
  });
}
