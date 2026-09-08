import 'dart:async';

import 'package:bestie/src/app/status_bar/state/status_bar_input.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_logic.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_output.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';

/// Keeps the status band's readings current: the provider connection, the
/// account balance, re-fetched whenever the provider comes up or a turn
/// finishes, and how far along the sandbox is since startup.
@viewModel
class StatusBarCubit extends LogicBloc<StatusBarState> {
  StatusBarCubit({
    required ProviderUseCase providers,
    required ChatUseCase chat,
    required SandboxUseCase sandboxes,
  }) : _providers = providers,
       super(
         StatusBarLogic(providers: providers, chat: chat, sandboxes: sandboxes),
       ) {
    binding
      ..onOutput<StatusBarStateUpdated>((_) => emit(state))
      ..onOutput<RefreshCreditsRequested>(
        (_) => unawaited(_providers.refreshCredits()),
      );
    input(SandboxReadinessChanged(sandboxes.readiness));
    input(ProviderStatusChanged(providers.status));
  }

  final ProviderUseCase _providers;
}
