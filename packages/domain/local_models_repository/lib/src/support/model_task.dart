/// Whether a model is a chat model, from what the Hub files it under, its
/// repo's name, or how its GGUF header pools.
library;

import 'package:local_models_repository/src/models/unsupported_reason.dart';

/// Hub pipeline tags of tasks that answer in text.
const _textGenerationTasks = {
  'text-generation',
  'text2text-generation',
  'conversational',
  'image-text-to-text',
  'video-text-to-text',
  'audio-text-to-text',
  'any-to-any',
  'visual-question-answering',
  'translation',
  'summarization',
};

const _embeddingTask = NotAChatModel('feature-extraction');
const _rerankingTask = NotAChatModel('text-ranking');

/// Why [repo] cannot chat, or null when it may. The Hub's [pipelineTag]
/// decides; a repo filed under no task, as many GGUF repos are, is judged
/// by the words of its name instead.
NotAChatModel? notAChatModel(String? pipelineTag, {required String repo}) =>
    switch (pipelineTag) {
      null => _notAChatModelByName(repo),
      final task when _textGenerationTasks.contains(task) => null,
      final task => NotAChatModel(task),
    };

NotAChatModel? _notAChatModelByName(String repo) {
  final words = repo
      .substring(repo.indexOf('/') + 1)
      .toLowerCase()
      .split(RegExp('[^a-z0-9]+'));
  if (words.any((word) => word.startsWith('rerank'))) return _rerankingTask;
  if (words.any((word) => word == 'embed' || word.startsWith('embedding'))) {
    return _embeddingTask;
  }
  return null;
}

/// Why a model whose header pools its output as [poolingType] cannot chat,
/// or null when it does not pool. Embedding and reranking models are the
/// ones that pool; type 4 ranks.
NotAChatModel? notAChatModelPooling(int? poolingType) => switch (poolingType) {
  null || 0 || -1 => null,
  4 => _rerankingTask,
  _ => _embeddingTask,
};
