import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/local_models_repository.dart';
import 'package:local_models_repository/src/models/quant_type.dart';
import 'package:local_models_repository/src/models/repo_resolution.dart';
import 'package:local_models_repository/src/models/unsupported_reason.dart';
import 'package:local_models_repository/src/support/gguf_file_name.dart';
import 'package:local_models_repository/src/support/model_family.dart';
import 'package:local_models_repository/src/support/model_task.dart';
import 'package:path/path.dart' as p;

/// Reads a Hugging Face repo and lists the quants bestie could download and
/// run, unless the Hub's task or the repo's name show it is no chat
/// model. Split files
/// are grouped into one quant, vision projectors are left out, and quants
/// with an unknown quantization or a missing file are dropped. The
/// architecture and chat template are checked when the Hub has
/// read them from the repo's GGUFs; otherwise the header decides once the
/// file is on disk. The repo is named as the Hub spells it, so one repo
/// never lands in two folders that differ only in case.
@PartOf(LocalModelsRepository)
class RepoResolver {
  const RepoResolver(this._hub);

  final HubClient _hub;

  /// [inLibrary] holds the download ids already downloaded or on their way.
  Future<RepoResolution> resolve(
    String repo, {
    required Set<String> inLibrary,
  }) async {
    final id = RepoId.tryParse(repo);
    if (id == null) return RepoNotFound(repo: repo);
    return switch (await _hub.getModel(id)) {
      HfRepoResolved(:final model) => _offer(
        RepoId.tryParse(model.id) ?? id,
        model,
        inLibrary,
      ),
      HfRepoNotFound() => RepoNotFound(repo: repo),
      HfRequestFailed(:final message) => RepoLookupFailed(
        repo: repo,
        message: message,
      ),
    };
  }

  RepoResolution _offer(RepoId id, HfModel model, Set<String> inLibrary) {
    final repo = id.fullName;
    final groups = _groupByModel(model.siblings ?? const []);
    final notChat = notAChatModel(model.pipelineTag, repo: repo);
    final architecture = model.gguf?.architecture;
    final match = switch (architecture) {
      null => null,
      final architecture => profileFor(architecture, model.gguf?.chatTemplate),
    };
    final quants = [
      for (final files in groups)
        ?_quantOf(id, model.sha, files)?.within(inLibrary),
    ]..sort((first, second) => first.sizeBytes.compareTo(second.sizeBytes));
    return switch (match) {
      _ when groups.isEmpty => RepoUnrunnable(
        repo: repo,
        reason: const NoGgufFiles(),
      ),
      _ when notChat != null => RepoUnrunnable(repo: repo, reason: notChat),
      ProfileUnmatched(:final reason) => RepoUnrunnable(
        repo: repo,
        reason: reason,
      ),
      _ when quants.isEmpty => RepoUnrunnable(
        repo: repo,
        reason: NoSupportedQuants([
          ...{
            for (final files in groups)
              ?GgufFileName(files.first.relativeFilename).quantLabel,
          },
        ]),
      ),
      _ => RepoResolved(
        repo: repo,
        revision: model.sha,
        architecture: architecture,
        profile: switch (match) {
          ProfileMatched(:final profile) => profile,
          _ => null,
        },
        contextLength: model.gguf?.contextLength,
        parameterCount: model.gguf?.total,
        quants: quants,
      ),
    };
  }

  /// Model files grouped by the model they belong to, each group in file
  /// order.
  static List<List<SiblingInfo>> _groupByModel(List<SiblingInfo> siblings) {
    final groups = <String, List<SiblingInfo>>{};
    for (final sibling in siblings) {
      final name = GgufFileName(sibling.relativeFilename);
      if (!name.isModel) continue;
      groups
          .putIfAbsent(
            p.url.join(p.url.dirname(sibling.relativeFilename), name.stem),
            () => [],
          )
          .add(sibling);
    }
    return [
      for (final files in groups.values)
        files..sort(
          (first, second) =>
              first.relativeFilename.compareTo(second.relativeFilename),
        ),
    ];
  }

  RepoQuant? _quantOf(RepoId id, String? revision, List<SiblingInfo> files) {
    final name = GgufFileName(files.first.relativeFilename);
    final label = name.quantLabel ?? '';
    final type = QuantType.fromLabel(label);
    final sized = [
      for (final file in files)
        if (file.lfs?.size ?? file.size case final size?)
          RepoFile(
            path: file.relativeFilename,
            url: _hub.resolveFileUrl(
              id,
              file.relativeFilename,
              revision: revision ?? 'main',
            ),
            sizeBytes: size,
            sha256: file.lfs?.sha256,
          ),
    ];
    if (type == null || sized.length != name.shardCount) return null;
    return RepoQuant(
      repo: id.fullName,
      revision: revision,
      label: label,
      type: type,
      files: sized,
      inLibrary: false,
    );
  }
}
