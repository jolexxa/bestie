import 'package:bestie_ui/src/banner/banner_notifier.dart';
import 'package:intentions/intentions.dart';

@model
class BannerData {
  BannerData({required this.notification});

  final BannerNotification notification;

  /// Number of revealed rows during the vertical unclip animation.
  /// Grows from 0 to the banner's full height.
  int revealStep = 0;

  /// Columns the banner is shifted right by during the slide-out
  /// animation. 0 = at rest, grows until the banner is off screen.
  int slideOffset = 0;
}
