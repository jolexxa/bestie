import 'dart:async';

import 'package:app_terminal_environment_use_case/app_terminal_environment_use_case.dart';
import 'package:bestie/src/app/app_context.dart';
import 'package:bestie/src/app/app_theme_provider.dart';
import 'package:bestie/src/app/router/router_component.dart';
import 'package:bestie/src/common/theme_effects/theme_effects_scope.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Builds the provider tree and runs the TUI.
Future<void> runBestieApp(AppContext deps) {
  return runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: deps.platform),
        RepositoryProvider.value(value: deps.platformRepository),
        RepositoryProvider.value(value: deps.appTerminalEnvironmentUseCase),
        RepositoryProvider.value(value: deps.appShellUseCase),
        RepositoryProvider.value(value: deps.mascotUseCase),
        RepositoryProvider.value(value: deps.terminalHost),
        RepositoryProvider.value(value: deps.shellUseCase),
        RepositoryProvider.value(value: deps.configUseCase),
        RepositoryProvider.value(value: deps.configKeys.app),
        RepositoryProvider.value(value: deps.configLayout),
        RepositoryProvider.value(value: deps.appInfo),
        RepositoryProvider.value(value: deps.credits),
        RepositoryProvider.value(value: deps.toolDefinitions),
        RepositoryProvider.value(value: deps.providerUseCase),
        RepositoryProvider.value(value: deps.agentRepository),
        RepositoryProvider.value(value: deps.chatUseCase),
        RepositoryProvider.value(value: deps.sandboxUseCase),
        RepositoryProvider.value(value: deps.toolsUseCase),
        RepositoryProvider.value(value: deps.commandsUseCase),
      ],
      child: const BestieApp(),
    ),
  );
}

@view
class BestieApp extends StatefulComponent {
  const BestieApp({super.key});

  @override
  State<BestieApp> createState() => _BestieAppState();
}

class _BestieAppState extends State<BestieApp> {
  StreamSubscription<int>? _exitSub;

  @override
  void initState() {
    super.initState();
    final environment = RepositoryProvider.of<AppTerminalEnvironmentUseCase>(
      context,
    )..reassertInputCapture();
    // The use case owns the quit intent; the view performs the framework
    // teardown — the same path Ctrl+C already unwinds through.
    _exitSub = environment.exitRequested.listen(
      (code) => TerminalBinding.instance.requestShutdown(code),
    );
  }

  @override
  void dispose() {
    unawaited(_exitSub?.cancel());
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return const AppThemeProvider(
      child: ThemeEffectsScope(child: Router()),
    );
  }
}
