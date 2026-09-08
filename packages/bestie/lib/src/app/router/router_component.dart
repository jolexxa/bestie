import 'dart:async';

import 'package:app_shell_use_case/app_shell_use_case.dart';
import 'package:app_terminal_environment_use_case/app_terminal_environment_use_case.dart';
import 'package:bestie/src/app/router/router.dart';
import 'package:bestie/src/app/status_bar/status_bar.dart';
import 'package:bestie/src/common/theme_effects/theme_effects_scope.dart';
import 'package:bestie_chat_view/bestie_chat_view.dart';
import 'package:bestie_config_view/bestie_config_view.dart';
import 'package:bestie_palette_view/bestie_palette_view.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Routes between primary app modes and hosts the config overlay.
///
/// The status band sits above the modes, inside the app's padding. All
/// modes remain mounted in a [Stack] so state is preserved across toggles.
/// Only the active mode receives keyboard focus. The config overlay renders
/// on top when open, blocking input to modes below.
@view
class Router extends StatefulComponent {
  const Router({super.key});

  /// Returns the [RouterCubit] from the nearest ancestor.
  static RouterCubit of(BuildContext context) =>
      BlocProvider.of<RouterCubit>(context, listen: false);

  @override
  State<Router> createState() => _RouterState();
}

class _RouterState extends State<Router> {
  final BannerNotifier _bannerNotifier = BannerNotifier();

  @override
  void dispose() {
    unawaited(_bannerNotifier.dispose());
    super.dispose();
  }

  static const Map<AppMode, Component> _views = {
    AppMode.chat: ChatPageView(key: ValueKey(AppMode.chat)),
  };

  List<Component> _orderedViews(AppMode mode) {
    return [
      for (final entry in _views.entries)
        if (entry.key != mode) entry.value,
      _views[mode]!,
    ];
  }

  @override
  Component build(BuildContext context) {
    final appShell = RepositoryProvider.of<AppShellUseCase>(context);
    final environment = RepositoryProvider.of<AppTerminalEnvironmentUseCase>(
      context,
    );
    return Provider<BannerNotifier>(
      value: _bannerNotifier,
      child: BlocProvider<RouterCubit>.create(
        create: (_) => RouterCubit(appShell: appShell),
        child: Builder(
          builder: (routerContext) {
            final routerCubit = BlocProvider.of<RouterCubit>(
              routerContext,
              listen: false,
            );
            return ConfigComponent(
              configOpenChanges: appShell.configOpenChanges,
              onCloseRequested: appShell.closeConfig,
              child: PaletteComponent(
                paletteOpenChanges: appShell.paletteOpenChanges,
                onCloseRequested: appShell.closePalette,
                child: BlocBuilder<RouterCubit, RouterState>(
                  builder: (context, state) {
                    return Provider<RouterContext>(
                      value: RouterContext(
                        mode: state.mode,
                        overlayOpen: state.overlayOpen,
                        switchToMode: routerCubit.switchToMode,
                      ),
                      child: Builder(
                        builder: (ctx) {
                          return InputActions(
                            actions: [
                              KeyAction(
                                label: 'Quit',
                                key: LogicalKey.keyC,
                                ctrl: true,
                                index: 1000,
                                onActivate: environment.quit,
                              ),
                              KeyAction(
                                label: 'Config',
                                key: LogicalKey.keyO,
                                ctrl: true,
                                index: 900,
                                onActivate: () => Router.of(ctx).toggleConfig(),
                              ),
                              KeyAction(
                                label: 'Palette',
                                key: LogicalKey.keyP,
                                ctrl: true,
                                index: 850,
                                onActivate: () =>
                                    Router.of(ctx).togglePalette(),
                              ),
                            ],
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    color: AppTheme.of(ctx).background,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            top: appEdgeInset,
                                            left: appEdgeInset,
                                            right: appEdgeInset,
                                          ),
                                          child: StatusBarComponent(),
                                        ),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              ..._orderedViews(state.mode),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                FullScreenModal(
                                  open: state.configOpen,
                                  onDismiss: appShell.closeConfig,
                                  child: const ConfigPageView(),
                                ),
                                FullScreenModal(
                                  open: state.paletteOpen,
                                  onDismiss: appShell.closePalette,
                                  child: const PalettePageView(),
                                ),
                                Positioned.fill(
                                  child: const Padding(
                                    padding: EdgeInsets.only(
                                      top: 3,
                                      right: 2,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: BannerOverlay(),
                                    ),
                                  ),
                                ),
                                if (ThemeEffectsScope.of(ctx)) ...[
                                  Positioned.fill(
                                    key: const ValueKey('matrix-overlay-slot'),
                                    child: const MatrixOverlay(),
                                  ),
                                  Positioned.fill(
                                    key: const ValueKey('snow-overlay-slot'),
                                    child: const SnowOverlay(),
                                  ),
                                  Positioned.fill(
                                    key: const ValueKey('wind-overlay-slot'),
                                    child: const WindOverlay(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
