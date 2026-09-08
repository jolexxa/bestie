import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

@model
sealed class WebSearchOutcome {
  const WebSearchOutcome();
}

@model
final class WebSearchSucceeded extends WebSearchOutcome {
  const WebSearchSucceeded({
    required this.query,
    required this.body,
    required this.results,
  });

  final String query;

  /// The rendered results, written out in full.
  final StoredBody body;

  final int results;
}

/// Nothing came back. Which of "there is nothing to find" and "no engine
/// answered" that means, an aggregate cannot say.
@model
final class WebSearchFoundNothing extends WebSearchOutcome {
  const WebSearchFoundNothing({required this.query});

  final String query;
}
