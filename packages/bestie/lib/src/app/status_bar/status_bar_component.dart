import 'dart:async';

import 'package:bestie/src/app/status_bar/state/status_bar_cubit.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_logic.dart';
import 'package:bestie/src/app/status_bar/state/status_bar_output.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

/// The one-row band across the top of the app.
@view
class StatusBarComponent extends StatelessComponent {
  const StatusBarComponent({super.key});

  @override
  Component build(BuildContext context) {
    final providers = RepositoryProvider.of<ProviderUseCase>(context);
    final chat = RepositoryProvider.of<ChatUseCase>(context);
    final sandboxes = RepositoryProvider.of<SandboxUseCase>(context);
    return BlocProvider<StatusBarCubit>.create(
      create: (_) => StatusBarCubit(
        providers: providers,
        chat: chat,
        sandboxes: sandboxes,
      ),
      child: const _StatusBarBand(),
    );
  }
}

/// Renders the band from the cubit's state and acts on the one signal a
/// rebuild cannot carry: the sandbox finishing a wait the user was shown.
@view
class _StatusBarBand extends StatefulComponent {
  const _StatusBarBand();

  @override
  State<_StatusBarBand> createState() => _StatusBarBandState();
}

class _StatusBarBandState extends State<_StatusBarBand> {
  StreamSubscription<SandboxBecameReady>? _readySub;
  StreamSubscription<SandboxForgotWriteGrants>? _forgotSub;

  @override
  void initState() {
    super.initState();
    final cubit = BlocProvider.of<StatusBarCubit>(context, listen: false);
    _readySub = cubit.outputsOf<SandboxBecameReady>().listen(
      (_) => _onSandboxReady(),
    );
    _forgotSub = cubit.outputsOf<SandboxForgotWriteGrants>().listen(
      (output) => _onWriteGrantsForgotten(output.count),
    );
  }

  @override
  void dispose() {
    unawaited(_readySub?.cancel());
    _readySub = null;
    unawaited(_forgotSub?.cancel());
    _forgotSub = null;
    super.dispose();
  }

  void _onSandboxReady() {
    if (!mounted) return;
    BannerNotifier.of(context).show(
      const BannerNotification(
        message: 'Sandbox ready',
        icon: '✓',
        style: BannerStyle.success,
      ),
    );
  }

  void _onWriteGrantsForgotten(int count) {
    if (!mounted) return;
    BannerNotifier.of(context).show(
      BannerNotification(
        message: writeGrantsForgottenReading(count),
        icon: '⛨',
        style: BannerStyle.info,
      ),
    );
  }

  @override
  Component build(BuildContext context) {
    return BlocBuilder<StatusBarCubit, StatusBarState>(
      builder: (context, state) => StatusBand(
        leading: creditsReading(state.credits),
        busy: sandboxReading(state.sandbox),
        trailing: providerReading(state.status),
      ),
    );
  }
}

/// Spend, plus the balance when the provider keeps one; nothing otherwise.
String creditsReading(CreditsResult? credits) => switch (credits) {
  CreditsFetched(:final credits) => switch (credits.remaining) {
    null => _spentReading(credits),
    final remaining =>
      '${_spentReading(credits)} · \$${remaining.toStringAsFixed(2)} left',
  },
  null || CreditsFailed() || CreditsUnsupported() => '',
};

String _spentReading(ProviderCredits credits) =>
    '\$${credits.spent.toStringAsFixed(2)}'
    '${spendWindowSuffix(credits.window)}';

/// Qualifies a spend figure by the span it covers.
String spendWindowSuffix(SpendWindow window) => switch (window) {
  SpendWindow.lifetime => ' lifetime',
  SpendWindow.monthToDate => ' this month',
};

/// Who is serving the chat, or how far along connecting to them is.
String providerReading(ProviderStatus status) => switch (status) {
  ProviderStatusUnconfigured() => 'no provider configured',
  ProviderStatusConnecting(:final model) => 'connecting to ${model.qualified}…',
  ProviderStatusReady(:final providerName, :final model) =>
    '$providerName · ${model.name}',
  ProviderStatusFailed(:final model, :final failure) =>
    '${model.qualified} · ${failure.message}',
};

/// What forgetting the write grants came to, by how many there were.
String writeGrantsForgottenReading(int count) => switch (count) {
  0 => 'No granted write directories to forget',
  1 => 'Forgot 1 granted write directory',
  _ => 'Forgot $count granted write directories',
};

/// What the sandbox is still busy with, or null once it has settled and
/// there is nothing to wait on.
String? sandboxReading(SandboxReadiness readiness) => switch (readiness) {
  SandboxAwaitingInitialization() => 'sandbox not initialized',
  SandboxPreparingHost() => 'preparing sandbox',
  SandboxProvisioning() => 'provisioning sandbox',
  SandboxInitializationFailed() => 'sandbox initialization failed',
  SandboxReady() => null,
};
