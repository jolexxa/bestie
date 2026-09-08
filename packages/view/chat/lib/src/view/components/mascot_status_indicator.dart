import 'dart:async';

import 'package:bestie_chat_view/src/state/chat_logic.dart';
import 'package:bestie_chat_view/src/state/models/chat_phase.dart';
import 'package:bestie_chat_view/src/view/components/mascot_icon.dart';
import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// The selected mascot plus its thinking/speaking bubbles.
@view
class MascotStatusIndicator extends StatefulComponent {
  const MascotStatusIndicator({required this.state, super.key});

  final ChatState state;

  @override
  State<MascotStatusIndicator> createState() => _MascotStatusIndicatorState();
}

class _MascotStatusIndicatorState extends State<MascotStatusIndicator> {
  late final MascotUseCase _mascotUseCase;
  late Mascot _mascot;
  StreamSubscription<Mascot>? _mascotSub;

  @override
  void initState() {
    super.initState();
    _mascotUseCase = RepositoryProvider.of<MascotUseCase>(context);
    _mascot = _mascotUseCase.mascot;
    _mascotSub = _mascotUseCase.mascotChanges.listen((mascot) {
      if (mascot == _mascot) return;
      setState(() => _mascot = mascot);
    });
  }

  @override
  void dispose() {
    unawaited(_mascotSub?.cancel());
    _mascotSub = null;
    super.dispose();
  }

  ChatState get _state => component.state;

  @override
  Component build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_bubbles, _mascotIcon],
    );
  }

  bool get _isTalking =>
      _state.generating && _state.phase == ChatPhase.responding;

  Component get _bubbles {
    if (_state.generating) {
      return _isTalking
          ? const MascotSpeakingBubblesAnimated()
          : const MascotThoughtBubblesAnimated();
    }
    if (_state.isReasoningActive) return const MascotThoughtBubbles();
    return const MascotBubblesBlank();
  }

  Component get _mascotIcon {
    final icons = mascotIconsFor(_mascot);
    if (!_state.generating) return MascotIconStatic(icons: icons);
    return _isTalking
        ? MascotIconTalkingAnimated(icons: icons)
        : MascotIconAnimated(icons: icons);
  }
}
