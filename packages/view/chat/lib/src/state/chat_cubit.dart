import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_chat_view/src/state/chat_data.dart';
import 'package:bestie_chat_view/src/state/chat_input.dart';
import 'package:bestie_chat_view/src/state/chat_logic.dart';
import 'package:bestie_chat_view/src/state/chat_output.dart';
import 'package:intentions/intentions.dart' hide useCase;
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';

@viewModel
class ChatCubit extends LogicBloc<ChatState> {
  ChatCubit({required ChatLogic logic}) : super(logic) {
    binding.onOutput<StateUpdated>((_) => emit(state));
  }

  ChatData get data => get<ChatData>();
  ChatUseCase get useCase => get<ChatUseCase>();

  void cycleReasoning() => input(const CycleReasoning());

  void initialize() {
    input(const Start());
  }

  void submit(String message) {
    input(Submit(message.trim()));
  }

  void cancel() => input(const Cancel());

  void clear() => input(const Clear());

  void escapePressed() => input(const EscapePressed());

  void enterRewind() => input(const EnterRewind());

  void rewindMoveUp() => input(const RewindMoveUp());

  void rewindMoveDown() => input(const RewindMoveDown());

  void confirmRewind() => input(const ConfirmRewind());

  void cancelRewind() => input(const CancelRewind());

  void moveSelectionUp() => input(const MoveSelectionUp());

  void moveSelectionDown() => input(const MoveSelectionDown());

  void selectTimelineItem(int index) => input(SelectTimelineItem(index));

  void revealTimelineItem(int index) => input(RevealTimelineItem(index));

  void selectVisibleItem(int index) => input(SelectVisibleItem(index));

  void enterSubagentZone() => input(const EnterSubagentZone());

  void exitSubagentZone() => input(const ExitSubagentZone());

  void moveSubagentUp() => input(const MoveSubagentUp());

  void moveSubagentDown() => input(const MoveSubagentDown());

  void stopHighlightedSubagent() => input(const StopHighlightedSubagent());

  void selectSubagentRow(int index) => input(SelectSubagentRow(index));

  void initializeSandbox() => input(const InitializeSandbox());

  void allowWriteAccess() => input(const AnswerWriteAccess(allow: true));

  void denyWriteAccess() => input(const AnswerWriteAccess(allow: false));

  void toggleWriteAccessChoice() => input(const ToggleWriteAccessChoice());

  void confirmWriteAccess() => input(const ConfirmWriteAccess());

  @override
  Future<void> close() async {
    if (isClosed) return;
    input(const Dispose());
    return super.close();
  }
}
