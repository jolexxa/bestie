import 'package:app_shell_use_case/app_shell_use_case.dart';
import 'package:bestie/src/app/router/state/router_input.dart';
import 'package:bestie/src/app/router/state/router_logic.dart';
import 'package:bestie/src/app/router/state/router_output.dart';
import 'package:bestie_ui/bestie_ui.dart' show AppMode;
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';

@viewModel
class RouterCubit extends LogicBloc<RouterState> {
  RouterCubit({required AppShellUseCase appShell})
    : _appShell = appShell,
      super(RouterLogic(appShell: appShell)) {
    binding.onOutput<RouterStateUpdated>((_) => emit(state));
  }

  final AppShellUseCase _appShell;

  void nextMode() => input(const NextMode());
  void previousMode() => input(const PreviousMode());
  void switchToMode(AppMode mode) => input(SwitchToMode(mode));
  void toggleConfig() => _appShell.toggleConfig();
  void togglePalette() => _appShell.togglePalette();
}
