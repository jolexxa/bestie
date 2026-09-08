import 'package:intentions/intentions.dart';

@model
sealed class BannerOutput {
  const BannerOutput();
}

@model
final class BannerUpdated extends BannerOutput {
  const BannerUpdated();
}

@model
final class BannerCompleted extends BannerOutput {
  const BannerCompleted();
}
