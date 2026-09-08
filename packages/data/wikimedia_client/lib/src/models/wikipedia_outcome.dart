import 'package:intentions/intentions.dart';
import 'package:wikimedia_client/src/models/wikipedia_topic.dart';

@model
sealed class WikipediaOutcome {
  const WikipediaOutcome();
}

@model
final class WikipediaTopicsFound extends WikipediaOutcome {
  const WikipediaTopicsFound(this.topics);

  final List<WikipediaTopic> topics;
}

@model
final class WikipediaUnavailable extends WikipediaOutcome {
  const WikipediaUnavailable(this.reason);

  final String reason;
}
