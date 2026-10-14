import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/models/unsupported_reason.dart';

/// How a search of Hugging Face for GGUF repos went.
@model
sealed class RepoSearchResult {
  const RepoSearchResult();
}

/// The repos the Hub listed, in its order.
@model
final class RepoSearchSucceeded extends RepoSearchResult {
  const RepoSearchSucceeded(this.repos);

  final List<RepoSummary> repos;
}

/// The Hub could not be asked, or answered with an error.
@model
final class RepoSearchFailed extends RepoSearchResult {
  const RepoSearchFailed(this.message);

  final String message;
}

/// The Hub did not answer within [timeout].
@model
final class RepoSearchTimedOut extends RepoSearchResult {
  const RepoSearchTimedOut(this.timeout);

  final Duration timeout;
}

/// One GGUF repo a search found.
@model
final class RepoSummary {
  const RepoSummary({
    required this.repo,
    this.downloads,
    this.likes,
    this.architecture,
    this.parameterCount,
    this.unrunnable,
  });

  /// `namespace/name`, as the Hub spells it.
  final String repo;

  final int? downloads;

  final int? likes;

  /// What the Hub read from the repo's GGUFs, when it read anything.
  final String? architecture;

  final int? parameterCount;

  /// Why nothing in the repo can run, when the Hub's reading already shows
  /// it; null when it may run.
  final UnrunnableReason? unrunnable;

  String get owner => repo.substring(0, repo.indexOf('/'));

  String get name => repo.substring(repo.indexOf('/') + 1);
}
