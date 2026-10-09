import 'package:intentions/intentions.dart';
import 'package:llm_model_profiles/llm_model_profiles.dart';
import 'package:local_models_repository/src/models/quant_type.dart';
import 'package:local_models_repository/src/models/unsupported_reason.dart';

/// What a Hugging Face repo offers to download.
@model
sealed class RepoResolution {
  const RepoResolution({required this.repo});

  /// `namespace/name`, spelled as the Hub spells it once it answered, or as
  /// asked for otherwise.
  final String repo;
}

/// The repo has quants bestie can run.
@model
final class RepoResolved extends RepoResolution {
  const RepoResolved({
    required super.repo,
    required this.quants,
    this.revision,
    this.architecture,
    this.profile,
    this.contextLength,
    this.parameterCount,
  });

  /// The commit every quant's files are pinned to.
  final String? revision;

  /// What the Hub read from the repo's GGUFs, when it read anything.
  final String? architecture;

  final ModelProfileId? profile;

  final int? contextLength;

  final int? parameterCount;

  /// Smallest first.
  final List<RepoQuant> quants;
}

@model
final class RepoNotFound extends RepoResolution {
  const RepoNotFound({required super.repo});
}

/// The repo exists, but nothing in it can run.
@model
final class RepoUnrunnable extends RepoResolution {
  const RepoUnrunnable({required super.repo, required this.reason});

  final UnrunnableReason reason;
}

/// The Hub could not be asked, or did not answer usefully.
@model
final class RepoLookupFailed extends RepoResolution {
  const RepoLookupFailed({required super.repo, required this.message});

  final String message;
}

/// One quant of a repo: a single GGUF, or every file of a split one.
@model
final class RepoQuant {
  const RepoQuant({
    required this.repo,
    required this.label,
    required this.type,
    required this.files,
    required this.inLibrary,
    this.revision,
  });

  final String repo;

  final String? revision;

  /// As the file names spell it, e.g. `Q4_K_XL`.
  final String label;

  /// The quantization behind [label].
  final QuantType type;

  /// In download order; a split model's first file comes first.
  final List<RepoFile> files;

  /// Whether it is already downloaded or on its way.
  final bool inLibrary;

  /// The repo and the first file's path, which no other quant shares.
  String get downloadId => '$repo:${files.first.path}';

  /// This quant, in the library when [downloadIds] holds its download.
  RepoQuant within(Set<String> downloadIds) => RepoQuant(
    repo: repo,
    revision: revision,
    label: label,
    type: type,
    files: files,
    inLibrary: downloadIds.contains(downloadId),
  );

  int get sizeBytes => files.fold(0, (sum, file) => sum + file.sizeBytes);

  QualityTier get tier => type.tier;
}

/// One file of a quant.
@model
final class RepoFile {
  const RepoFile({
    required this.path,
    required this.url,
    required this.sizeBytes,
    this.sha256,
  });

  /// Relative to the repo root.
  final String path;

  final Uri url;

  final int sizeBytes;

  final String? sha256;
}
