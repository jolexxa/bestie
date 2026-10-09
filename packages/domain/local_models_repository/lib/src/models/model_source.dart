import 'package:intentions/intentions.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// Where a local model came from.
@model
sealed class ModelSource {
  const ModelSource();

  /// How the model index records it.
  ModelProvenance get provenance;
}

/// Downloaded by bestie into its models folder. Only these may be deleted.
@model
final class DownloadedSource extends ModelSource {
  const DownloadedSource({
    required this.downloadId,
    required this.repo,
    required this.file,
    this.revision,
  });

  final String downloadId;

  /// `namespace/name` on Hugging Face.
  final String repo;

  final String? revision;

  /// The first file's path within the repo.
  final String file;

  @override
  ModelProvenance get provenance =>
      ModelDownloaded(repo: repo, revision: revision, file: file);
}

/// Found by scanning a folder the user configured. Bestie never deletes it.
@model
final class ScannedSource extends ModelSource {
  const ScannedSource({required this.root, this.inferredRepo});

  /// The folder that was scanned.
  final String root;

  /// The Hugging Face repo the file's location suggests, if any.
  final InferredRepo? inferredRepo;

  @override
  ModelProvenance get provenance => ModelScanned(root: root);

  /// The same file, found in bestie's models folder rather than a folder of
  /// the user's.
  UntrackedSource get untracked =>
      UntrackedSource(root: root, inferredRepo: inferredRepo);
}

/// In bestie's models folder, but not downloaded by bestie: put there by
/// hand, or left behind by a download bestie no longer remembers. Bestie
/// never deletes it.
@model
final class UntrackedSource extends ModelSource {
  const UntrackedSource({required this.root, this.inferredRepo});

  /// The models folder.
  final String root;

  final InferredRepo? inferredRepo;

  @override
  ModelProvenance get provenance => ModelScanned(root: root);
}

/// A Hugging Face repo guessed from where a file sits, such as a Hugging Face
/// cache snapshot or an LM Studio `org/repo/file.gguf` folder. It is a guess:
/// nothing checked it against the Hub.
@model
final class InferredRepo {
  const InferredRepo({required this.repo, this.revision});

  /// `namespace/name`.
  final String repo;

  final String? revision;
}
