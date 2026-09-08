import 'package:bestie_ui/src/banner/banner_notifier.dart';
import 'package:bestie_ui/src/banner/state/banner_cubit.dart';
import 'package:bestie_ui/src/banner/state/banner_data.dart';
import 'package:bestie_ui/src/banner/state/banner_input.dart';
import 'package:bestie_ui/src/banner/state/banner_output.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

const Duration _revealTickDuration = Duration(milliseconds: 40);
const Duration _slideTickDuration = Duration(milliseconds: 30);

/// Full vertical extent of a fully-revealed banner, in rows.
const int bannerHeight = 3;

/// Full horizontal extent of a banner, in columns.
const int bannerWidth = 40;

/// Width of the darker accent gutter on the left of each banner.
const int bannerGutterWidth = 3;

/// Total distance, in columns, the banner travels during its slide-out
/// animation. Sized larger than [bannerWidth] so the banner clears the
/// surrounding overlay padding and exits at the actual screen edge.
const int bannerSlideDistance = 5;

const int _slideStepCols = 5;

@PartOf(BannerCubit)
final class BannerLogic extends LogicBlock<BannerState> {
  BannerLogic({required BannerNotification notification}) {
    set(BannerData(notification: notification));
    set(RevealingState());
    set(ShowingState());
    set(HidingState());
    set(DoneState());
  }

  @override
  Transition getInitialState() => to<RevealingState>();

  @override
  void onStart() => input(const BannerStarted());
}

@model
sealed class BannerState extends StateLogic<BannerState> {
  BannerData get data => get<BannerData>();

  BannerNotification get notification => data.notification;

  /// Currently revealed height in rows. 0 = invisible, [bannerHeight] = full.
  int get revealHeight => bannerHeight;

  /// Columns the banner is shifted right by for the slide-out animation.
  int get slideOffset => data.slideOffset;
}

@model
final class RevealingState extends BannerState {
  RevealingState() {
    on<BannerStarted>((_) {
      data.revealStep = 0;
      data.slideOffset = 0;
      output(const BannerUpdated());
      _scheduleTick();
      return toSelf();
    });

    on<RevealTick>((_) {
      data.revealStep++;
      if (data.revealStep >= bannerHeight) {
        return to<ShowingState>();
      }
      output(const BannerUpdated());
      _scheduleTick();
      return toSelf();
    });
  }

  void _scheduleTick() {
    async(
      Future<void>.delayed(_revealTickDuration),
    ).input((_) => const RevealTick());
  }

  @override
  int get revealHeight => data.revealStep;
}

@model
final class ShowingState extends BannerState {
  ShowingState() {
    onEnter(() {
      data.slideOffset = 0;
      output(const BannerUpdated());
      async(
        Future<void>.delayed(notification.duration),
      ).input((_) => const ShowComplete());
    });

    on<ShowComplete>((_) => to<HidingState>());
  }
}

@model
final class HidingState extends BannerState {
  HidingState() {
    onEnter(() {
      data.slideOffset = 0;
      output(const BannerUpdated());
      _scheduleTick();
    });

    on<HideTick>((_) {
      data.slideOffset += _slideStepCols;
      if (data.slideOffset >= bannerWidth + bannerSlideDistance) {
        return to<DoneState>();
      }
      output(const BannerUpdated());
      _scheduleTick();
      return toSelf();
    });
  }

  void _scheduleTick() {
    async(
      Future<void>.delayed(_slideTickDuration),
    ).input((_) => const HideTick());
  }
}

@model
final class DoneState extends BannerState {
  DoneState() {
    onEnter(() => output(const BannerCompleted()));
  }

  @override
  int get revealHeight => 0;
}
