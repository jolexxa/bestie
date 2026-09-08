import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:bestie_config_view/src/state/config_input.dart';
import 'package:bestie_config_view/src/state/config_logic.dart';
import 'package:bestie_config_view/src/state/config_output.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';

/// View-model for the config overlay.
@viewModel
class ConfigCubit extends LogicBloc<ConfigState> {
  ConfigCubit({
    required this.configUseCase,
    required this.layout,
    required int toolCount,
    ConfigScope? targetScope,
  }) : super(ConfigLogic(configUseCase: configUseCase, layout: layout)) {
    binding
      ..onOutput<ConfigStateUpdated>((_) => emit(state))
      ..onOutput<CloseRequested>((_) => onCloseRequested?.call())
      ..onOutput<CursorMoved>((output) => onCursorMoved?.call(output.index))
      ..onOutput<PageChanged>((_) => onPageChanged?.call());
    input(Initialize(targetScope: targetScope, toolCount: toolCount));
  }

  final ConfigUseCase configUseCase;

  /// The fully-built layout for this overlay, injected from bootstrap.
  final ConfigLayout layout;

  void Function()? onCloseRequested;

  /// Called when the row selection moves. The view scrolls to keep the
  /// selected row visible.
  void Function(int index)? onCursorMoved;

  /// Called when the selected page changes. The view resets its scroll
  /// position to the top.
  void Function()? onPageChanged;

  /// The resolver for reading/writing config values.
  ConfigView get resolver => configUseCase;

  // ── Input forwarders ────────────────────────────────────

  void moveSelection(int delta) => input(MoveSelection(delta));
  void changePage(int delta) => input(ChangePage(delta));
  void adjustValue(int delta) => input(InlineAdjust(delta));
  void beginEdit() => input(const BeginEdit());
  void resetParam() => input(const ResetParam());
  void confirmEdit(String text) => input(ConfirmEdit(text));
  void cancelEdit() => input(const CancelEdit());
  void requestClose() => input(const RequestClose());

  /// Called by the hosting view when the config sheet becomes visible.
  void openSession({required int toolCount, ConfigScope? targetScope}) {
    configUseCase.beginSession();
    input(Initialize(targetScope: targetScope, toolCount: toolCount));
  }

  /// Called by the hosting view when the config sheet becomes hidden.
  void closeSession() {
    if (state.editing) input(const CancelEdit());
    configUseCase.endSession();
  }
}
