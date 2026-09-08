import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:bestie_palette_view/src/state/palette_input.dart';
import 'package:bestie_palette_view/src/state/palette_logic.dart';
import 'package:bestie_palette_view/src/state/palette_output.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';

/// View-model for the command palette overlay.
@viewModel
class PaletteCubit extends LogicBloc<PaletteState> {
  PaletteCubit({required CommandsUseCase commands})
    : super(PaletteLogic(commands: commands.commands)) {
    binding
      ..onOutput<PaletteStateUpdated>((_) => emit(state))
      ..onOutput<CloseRequested>((_) => onCloseRequested?.call())
      ..onOutput<CursorMoved>((output) => onCursorMoved?.call(output.index));
  }

  void Function()? onCloseRequested;

  /// Called when the list selection moves. The view scrolls to keep the
  /// selected row visible.
  void Function(int index)? onCursorMoved;

  // ── Input forwarders ────────────────────────────────────

  void queryChanged(String query) => input(QueryChanged(query));
  void moveSelection(int delta) => input(MoveSelection(delta));
  void activate() => input(const Activate());
  void optionQueryChanged(String query) => input(OptionQueryChanged(query));
  void toggleOption() => input(const ToggleOption());
  void submitText(String text) => input(SubmitText(text));
  void submitChoice() => input(const SubmitChoice());
  void back() => input(const Back());
  void requestClose() => input(const RequestClose());

  /// Called by the hosting view when the palette becomes visible.
  void openSession() => input(const OpenPalette());

  /// Called by the hosting view when the palette becomes hidden.
  void closeSession() => input(const ClosePalette());
}
