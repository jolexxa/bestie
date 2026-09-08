import 'package:intentions/intentions.dart';

@model
sealed class BannerInput {
  const BannerInput();
}

@model
final class BannerStarted extends BannerInput {
  const BannerStarted();
}

@model
final class RevealTick extends BannerInput {
  const RevealTick();
}

@model
final class ShowComplete extends BannerInput {
  const ShowComplete();
}

@model
final class HideTick extends BannerInput {
  const HideTick();
}
