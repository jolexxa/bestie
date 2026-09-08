import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_cubit.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_data.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_input.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_output.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

@PartOf(StatusBarCubit)
final class StatusBarLogic extends LogicBlock<StatusBarState> {
  StatusBarLogic({
    required ProviderUseCase providers,
    required ChatUseCase chat,
    required SandboxUseCase sandboxes,
  }) : _providers = providers,
       _chat = chat,
       _sandboxes = sandboxes {
    set(
      StatusBarData(
        status: const ProviderStatusUnconfigured(),
        credits: providers.lastCredits,
        sandbox: const SandboxReady(),
      ),
    );
    set(WatchingState());
  }

  final ProviderUseCase _providers;
  final ChatUseCase _chat;
  final SandboxUseCase _sandboxes;
  final List<StreamSubscription<void>> _subs = [];

  @override
  void onStart() {
    _subs
      ..add(
        _providers.statusStream.listen(
          (status) => input(ProviderStatusChanged(status)),
        ),
      )
      ..add(
        _providers.creditsStream.listen(
          (credits) => input(CreditsChanged(credits)),
        ),
      )
      ..add(
        _chat.conversationStream.listen(
          (_) => input(ConversationChanged(_chat.conversationState)),
        ),
      )
      ..add(
        _sandboxes.readinessStream.listen(
          (readiness) => input(SandboxReadinessChanged(readiness)),
        ),
      )
      ..add(
        _sandboxes.writeGrantsForgotten.listen(
          (forgotten) => input(WriteGrantsForgottenReported(forgotten)),
        ),
      );
  }

  @override
  void onStop() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }

  @override
  Transition getInitialState() => to<WatchingState>();
}

// ── States ────────────────────────────────────────────────

@model
sealed class StatusBarState extends StateLogic<StatusBarState> {
  StatusBarData get data => get<StatusBarData>();

  /// Where the provider connection stands.
  ProviderStatus get status => data.status;

  /// The last balance heard from the provider, if any.
  CreditsResult? get credits => data.credits;

  /// How far along the session's sandbox is since startup.
  SandboxReadiness get sandbox => data.sandbox;
}

@model
final class WatchingState extends StatusBarState {
  WatchingState() {
    on<ProviderStatusChanged>((input) {
      final cameUp =
          input.status is ProviderStatusReady &&
          data.status is! ProviderStatusReady;
      data.status = input.status;
      if (cameUp) output(const RefreshCreditsRequested());
      output(const StatusBarStateUpdated());
      return toSelf();
    });
    on<CreditsChanged>((input) {
      data.credits = input.credits;
      output(const StatusBarStateUpdated());
      return toSelf();
    });
    on<ConversationChanged>((input) {
      final settled =
          data.turnInFlight && input.conversation is ConversationIdle;
      data.turnInFlight = input.conversation is TurnInProgress;
      if (settled) output(const RefreshCreditsRequested());
      return toSelf();
    });
    on<SandboxReadinessChanged>((input) {
      final cameUp =
          input.readiness is SandboxReady && data.sandbox is! SandboxReady;
      data.sandbox = input.readiness;
      if (cameUp) output(const SandboxBecameReady());
      output(const StatusBarStateUpdated());
      return toSelf();
    });
    on<WriteGrantsForgottenReported>((input) {
      output(SandboxForgotWriteGrants(input.forgotten.directories.length));
      return toSelf();
    });
  }
}
