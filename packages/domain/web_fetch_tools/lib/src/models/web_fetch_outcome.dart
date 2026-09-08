import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

@model
sealed class WebFetchOutcome {
  const WebFetchOutcome();
}

@model
final class WebFetchSucceeded extends WebFetchOutcome {
  const WebFetchSucceeded({
    required this.url,
    required this.title,
    required this.body,
  });

  final String url;
  final String? title;

  /// The page's readable content, written out in full.
  final StoredBody body;
}

@model
final class WebFetchUrlInvalid extends WebFetchOutcome {
  const WebFetchUrlInvalid({required this.url});

  final String url;
}

/// The page came back, but there was no article in it.
@model
final class WebFetchFoundNoContent extends WebFetchOutcome {
  const WebFetchFoundNoContent({required this.url});

  final String url;
}

@model
final class WebFetchFailed extends WebFetchOutcome {
  const WebFetchFailed({required this.url, required this.reason});

  final String url;
  final String reason;
}
