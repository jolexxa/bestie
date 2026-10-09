import 'dart:async';

import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/local_models_repository.dart';
import 'package:local_models_repository/src/models/repo_search.dart';
import 'package:local_models_repository/src/support/model_family.dart';
import 'package:local_models_repository/src/support/model_task.dart';

/// Searches Hugging Face for repos with GGUF files, most downloaded first,
/// marking the ones that are no chat model or whose architecture or chat
/// template bestie cannot run.
@PartOf(LocalModelsRepository)
class RepoSearcher {
  const RepoSearcher(this._hub);

  final HubClient _hub;

  static const List<ModelExpandField> _expand = [
    ModelExpandField.author,
    ModelExpandField.downloads,
    ModelExpandField.likes,
    ModelExpandField.gguf,
    ModelExpandField.pipelineTag,
  ];

  /// An empty [query] lists the most downloaded GGUF repos.
  Future<RepoSearchResult> search(
    String query, {
    required int limit,
    required Duration timeout,
  }) async {
    final trimmed = query.trim();
    try {
      final result = await _hub
          .searchModels(
            search: trimmed.isEmpty ? null : trimmed,
            filter: 'gguf',
            sort: 'downloads',
            direction: SortDirection.descending,
            limit: limit,
            expand: _expand,
          )
          .timeout(timeout);
      return switch (result) {
        HfSearchSucceeded(:final page) => RepoSearchSucceeded([
          for (final model in page.items) _summaryOf(model),
        ]),
        HfRequestFailed(:final message) => RepoSearchFailed(message),
      };
    } on TimeoutException {
      return RepoSearchTimedOut(timeout);
    }
  }

  static RepoSummary _summaryOf(HfModel model) {
    final architecture = model.gguf?.architecture;
    return RepoSummary(
      repo: model.id,
      downloads: model.downloads,
      likes: model.likes,
      architecture: architecture,
      parameterCount: model.gguf?.total,
      unrunnable:
          notAChatModel(model.pipelineTag, repo: model.id) ??
          switch (architecture) {
            null => null,
            final architecture => switch (profileFor(
              architecture,
              model.gguf?.chatTemplate,
            )) {
              ProfileMatched() => null,
              ProfileUnmatched(:final reason) => reason,
            },
          },
    );
  }
}
