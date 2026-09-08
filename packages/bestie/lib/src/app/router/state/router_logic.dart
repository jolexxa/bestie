import 'dart:async';

import 'package:app_shell_use_case/app_shell_use_case.dart';
import 'package:bestie/src/app/router/state/router_cubit.dart';
import 'package:bestie/src/app/router/state/router_data.dart';
import 'package:bestie/src/app/router/state/router_input.dart';
import 'package:bestie/src/app/router/state/router_output.dart';
import 'package:bestie_ui/bestie_ui.dart' show AppMode;
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

@PartOf(RouterCubit)
final class RouterLogic extends LogicBlock<RouterState> {
  RouterLogic({required AppShellUseCase appShell}) : _appShell = appShell {
    set(RouterData());
    set(RoutingState());
  }

  final AppShellUseCase _appShell;
  final List<StreamSubscription<bool>> _overlaySubs = [];

  @override
  void onStart() {
    _overlaySubs
      ..add(
        _appShell.configOpenChanges.listen(
          (open) => input(ConfigOpenChanged(open: open)),
        ),
      )
      ..add(
        _appShell.paletteOpenChanges.listen(
          (open) => input(PaletteOpenChanged(open: open)),
        ),
      );
  }

  @override
  void onStop() {
    for (final sub in _overlaySubs) {
      unawaited(sub.cancel());
    }
    _overlaySubs.clear();
  }

  @override
  Transition getInitialState() => to<RoutingState>();
}

// ── States ────────────────────────────────────────────────

@model
sealed class RouterState extends StateLogic<RouterState> {
  RouterData get data => get<RouterData>();

  /// The current app mode.
  AppMode get mode => data.mode;

  /// Whether the config overlay is open.
  bool get configOpen => data.configOpen;

  /// Whether the command palette overlay is open.
  bool get paletteOpen => data.paletteOpen;

  /// Whether any modal overlay is covering the modes.
  bool get overlayOpen => configOpen || paletteOpen;
}

@model
final class RoutingState extends RouterState {
  RoutingState() {
    on<NextMode>((_) {
      data.mode = data.mode.next;
      output(const RouterStateUpdated());
      return toSelf();
    });
    on<PreviousMode>((_) {
      data.mode = data.mode.previous;
      output(const RouterStateUpdated());
      return toSelf();
    });
    on<SwitchToMode>((input) {
      if (input.mode == data.mode) return toSelf();
      data.mode = input.mode;
      output(const RouterStateUpdated());
      return toSelf();
    });
    on<ConfigOpenChanged>((input) {
      data.configOpen = input.open;
      output(const RouterStateUpdated());
      return toSelf();
    });
    on<PaletteOpenChanged>((input) {
      data.paletteOpen = input.open;
      output(const RouterStateUpdated());
      return toSelf();
    });
  }
}
