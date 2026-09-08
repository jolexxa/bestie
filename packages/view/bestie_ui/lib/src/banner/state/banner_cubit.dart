import 'package:bestie_ui/src/banner/banner_notifier.dart';
import 'package:bestie_ui/src/banner/state/banner_logic.dart';
import 'package:bestie_ui/src/banner/state/banner_output.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_bloc_adapter/logic_bloc_adapter.dart';

@viewModel
class BannerCubit extends LogicBloc<BannerState> {
  BannerCubit({required BannerNotification notification})
    : super(BannerLogic(notification: notification)) {
    binding
      ..onOutput<BannerUpdated>((_) => emit(state))
      ..onOutput<BannerCompleted>((_) => onCompleted?.call());
  }

  /// Invoked when the banner finishes its full reveal/show/hide cycle.
  void Function()? onCompleted;
}
