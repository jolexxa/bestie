import 'package:arxiv_tools/src/models/paper_source.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

@model
sealed class ArxivSearchOutcome {
  const ArxivSearchOutcome();
}

@model
final class ArxivSearchSucceeded extends ArxivSearchOutcome {
  const ArxivSearchSucceeded({
    required this.query,
    required this.body,
    required this.papers,
    required this.sources,
  });

  final String query;

  /// The rendered papers, written out in full.
  final StoredBody body;

  final int papers;
  final List<PaperSource> sources;
}

@model
final class ArxivSearchFoundNothing extends ArxivSearchOutcome {
  const ArxivSearchFoundNothing({required this.query});

  final String query;
}

@model
final class ArxivSearchUnavailable extends ArxivSearchOutcome {
  const ArxivSearchUnavailable({required this.query, required this.reason});

  final String query;
  final String reason;
}
