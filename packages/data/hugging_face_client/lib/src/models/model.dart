import 'package:dart_mappable/dart_mappable.dart';
import 'package:hugging_face_client/src/models/gated_mode.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

part 'model.mapper.dart';

/// A model repository on the Hugging Face Hub.
///
/// Most fields are only present when the request asked for them via
/// `expand[]`.
@model
@MappableClass(includeCustomMappers: [GatedModeMapper()])
@immutable
class HfModel with HfModelMappable {
  /// Creates an [HfModel].
  const HfModel({
    required this.id,
    this.author,
    this.sha,
    this.lastModified,
    this.isPrivate,
    this.gated,
    this.isDisabled,
    this.downloads,
    this.likes,
    this.library,
    this.tags,
    this.pipelineTag,
    this.createdAt,
    this.downloadsAllTime,
    this.trendingScore,
    this.usedStorage,
    this.siblings,
    this.gguf,
  });

  /// The full model identifier, e.g. `"mlx-community/Llama-3.2-1B-Instruct-4bit"`.
  final String id;

  /// The model author (user or organisation).
  final String? author;

  /// The latest commit SHA.
  final String? sha;

  /// When the model was last modified.
  final DateTime? lastModified;

  /// Whether this model is private.
  @MappableField(key: 'private')
  final bool? isPrivate;

  /// Gated access mode.
  final GatedMode? gated;

  /// Whether the model is disabled.
  @MappableField(key: 'disabled')
  final bool? isDisabled;

  /// Recent download count.
  final int? downloads;

  /// Like count.
  final int? likes;

  /// The library that produced this model (e.g. `"transformers"`).
  @MappableField(key: 'library_name')
  final String? library;

  /// Tags applied to this model.
  final List<String>? tags;

  /// Pipeline tag (e.g. `"text-generation"`).
  @MappableField(key: 'pipeline_tag')
  final String? pipelineTag;

  /// When the model was created.
  final DateTime? createdAt;

  /// All-time download count.
  final int? downloadsAllTime;

  /// Trending score.
  final int? trendingScore;

  /// Total storage used by the repository, in bytes.
  final int? usedStorage;

  /// Files in the repository.
  final List<SiblingInfo>? siblings;

  /// What the Hub read from the repository's GGUF files, when it has any.
  final HfGgufInfo? gguf;
}

/// Facts the Hub reads from a repository's GGUF files.
@model
@MappableClass()
@immutable
class HfGgufInfo with HfGgufInfoMappable {
  /// Creates an [HfGgufInfo].
  const HfGgufInfo({
    this.total,
    this.architecture,
    this.contextLength,
    this.chatTemplate,
  });

  /// Parameter count.
  final int? total;

  /// The `general.architecture`, e.g. `"qwen3"`.
  final String? architecture;

  /// The trained context length.
  @MappableField(key: 'context_length')
  final int? contextLength;

  /// The `tokenizer.chat_template`.
  @MappableField(key: 'chat_template')
  final String? chatTemplate;
}

/// A file in a model repository. [size], [blobId] and [lfs] are present
/// when the request asked for blob metadata.
@model
@MappableClass()
@immutable
class SiblingInfo with SiblingInfoMappable {
  /// Creates a [SiblingInfo].
  const SiblingInfo({
    required this.relativeFilename,
    this.size,
    this.blobId,
    this.lfs,
  });

  /// The file path relative to the repository root.
  @MappableField(key: 'rfilename')
  final String relativeFilename;

  /// File size in bytes.
  final int? size;

  /// Git blob identifier.
  final String? blobId;

  /// LFS metadata, if the file is stored in Git LFS.
  final LfsInfo? lfs;
}

/// Git LFS metadata for a file.
@model
@MappableClass()
@immutable
class LfsInfo with LfsInfoMappable {
  /// Creates an [LfsInfo].
  const LfsInfo({
    required this.sha256,
    required this.size,
    this.pointerSize,
  });

  /// SHA-256 hash of the file contents.
  final String sha256;

  /// File size in bytes.
  final int size;

  /// Size of the LFS pointer file in bytes.
  final int? pointerSize;
}
