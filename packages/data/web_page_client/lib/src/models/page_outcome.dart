import 'package:intentions/intentions.dart';

@model
sealed class PageOutcome {
  const PageOutcome();
}

@model
final class PageFetched extends PageOutcome {
  const PageFetched({
    required this.url,
    required this.text,
    required this.title,
  });

  final String url;

  /// The page's main content, stripped of navigation and markup.
  final String text;

  final String? title;
}

/// The page came back, but there was no article in it.
@model
final class PageHadNoContent extends PageOutcome {
  const PageHadNoContent();
}

/// The page did not come back at all.
@model
final class PageUnavailable extends PageOutcome {
  const PageUnavailable(this.reason);

  final String reason;
}
