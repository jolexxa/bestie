import 'package:arxiv_client/src/models/arxiv_paper.dart';
import 'package:intentions/intentions.dart';

@model
sealed class ArxivOutcome {
  const ArxivOutcome();
}

@model
final class ArxivPapersFound extends ArxivOutcome {
  const ArxivPapersFound(this.papers);

  final List<ArxivPaper> papers;
}

@model
final class ArxivUnavailable extends ArxivOutcome {
  const ArxivUnavailable(this.reason);

  final String reason;
}
