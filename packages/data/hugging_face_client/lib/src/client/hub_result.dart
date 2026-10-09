import 'package:hugging_face_client/src/client/paginated_response.dart';
import 'package:hugging_face_client/src/models/git.dart';
import 'package:hugging_face_client/src/models/model.dart';
import 'package:hugging_face_client/src/models/repo.dart';
import 'package:intentions/intentions.dart';

@model
sealed class HfSearchResult {
  const HfSearchResult();
}

@model
final class HfSearchSucceeded extends HfSearchResult {
  const HfSearchSucceeded(this.page);

  final PaginatedResponse<HfModel> page;
}

@model
sealed class HfRepoResult {
  const HfRepoResult();
}

@model
final class HfRepoResolved extends HfRepoResult {
  const HfRepoResolved(this.model);

  final HfModel model;
}

@model
sealed class HfTreeResult {
  const HfTreeResult();
}

@model
final class HfTreeListed extends HfTreeResult {
  const HfTreeListed(this.entries);

  final List<GitTreeEntry> entries;
}

/// The repository does not exist, or is private to someone else — the Hub
/// answers both the same way.
@model
final class HfRepoNotFound implements HfRepoResult, HfTreeResult {
  const HfRepoNotFound(this.repo);

  final RepoId repo;
}

/// The Hub could not be reached, answered with an error, or sent a body
/// that could not be understood.
@model
final class HfRequestFailed
    implements HfSearchResult, HfRepoResult, HfTreeResult {
  const HfRequestFailed({required this.message, this.statusCode});

  final String message;

  /// The HTTP status, when a response arrived at all.
  final int? statusCode;
}
