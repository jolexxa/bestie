import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:wikipedia_tools/src/models/topic_source.dart';

@model
sealed class WikipediaSearchOutcome {
  const WikipediaSearchOutcome();
}

@model
final class WikipediaSearchSucceeded extends WikipediaSearchOutcome {
  const WikipediaSearchSucceeded({
    required this.query,
    required this.body,
    required this.topics,
    required this.sources,
  });

  final String query;

  /// The rendered topics, written out in full.
  final StoredBody body;

  final int topics;
  final List<TopicSource> sources;
}

@model
final class WikipediaSearchFoundNothing extends WikipediaSearchOutcome {
  const WikipediaSearchFoundNothing({required this.query});

  final String query;
}

@model
final class WikipediaSearchUnavailable extends WikipediaSearchOutcome {
  const WikipediaSearchUnavailable({
    required this.query,
    required this.reason,
  });

  final String query;
  final String reason;
}
