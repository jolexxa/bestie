import 'package:intentions/intentions.dart';

@model
sealed class DownloadOutput {
  const DownloadOutput();
}

/// The download's status reads differently without its state changing, as
/// when more bytes arrive.
@model
final class DownloadUpdated extends DownloadOutput {
  const DownloadUpdated();
}
