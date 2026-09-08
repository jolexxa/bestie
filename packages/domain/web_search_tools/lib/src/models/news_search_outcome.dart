import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

@model
sealed class NewsSearchOutcome {
  const NewsSearchOutcome();
}

@model
final class NewsSearchSucceeded extends NewsSearchOutcome {
  const NewsSearchSucceeded({
    required this.query,
    required this.body,
    required this.results,
  });

  final String query;

  /// The rendered articles, written out in full.
  final StoredBody body;

  final int results;
}

/// Nothing came back. Which of "there is nothing to find" and "no engine
/// answered" that means, an aggregate cannot say.
@model
final class NewsSearchFoundNothing extends NewsSearchOutcome {
  const NewsSearchFoundNothing({required this.query});

  final String query;
}
