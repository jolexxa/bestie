import 'package:hugging_face_client/hugging_face_client.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/models/library_results.dart';
import 'package:local_models_repository/src/models/model_source.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_index_store/model_index_store.dart';
import 'package:path/path.dart' as p;

/// A download record checked against the models folder: its repo is a real
/// Hub id and every file lands inside the repo's folder, at the [paths]
/// worked out here and nowhere else.
@model
final class DownloadPlan {
  const DownloadPlan._({
    required this.record,
    required this.directory,
    required this.paths,
  });

  /// [record] as a plan under [modelsDir], or why it cannot be one. [paths]
  /// reads [modelsDir] the way the filesystem it sits on does.
  static DownloadPlanResult of(
    DownloadRecord record, {
    required String modelsDir,
    required p.Context paths,
  }) {
    final directory = paths.join(modelsDir, record.repo);
    final unsafe = record.files.where(
      (file) =>
          !paths.isRelative(file.path) ||
          !paths.isWithin(directory, paths.join(directory, file.path)),
    );
    return switch (RepoId.tryParse(record.repo)) {
      null => DownloadPlanInvalid(InvalidRepoId(record.repo)),
      _ when record.files.isEmpty => const DownloadPlanInvalid(
        NoDownloadFiles(),
      ),
      _ when unsafe.isNotEmpty => DownloadPlanInvalid(
        InvalidFilePath(unsafe.first.path),
      ),
      _ => DownloadPlanned(
        DownloadPlan._(
          record: record,
          directory: directory,
          paths: [
            for (final file in record.files)
              paths.normalize(paths.join(directory, file.path)),
          ],
        ),
      ),
    };
  }

  /// As the ledger last recorded it.
  final DownloadRecord record;

  /// The repo's folder under the models folder.
  final String directory;

  /// Every file's absolute path, the first file first.
  final List<String> paths;

  String get id => record.id;

  String get firstPath => paths.first;

  int get totalBytes => record.files.fold(0, (sum, file) => sum + file.bytes);

  DownloadedSource get source => DownloadedSource(
    downloadId: record.id,
    repo: record.repo,
    revision: record.revision,
    file: record.files.first.path,
  );

  DownloadJob get job => DownloadJob(
    directory: directory,
    files: [
      for (final file in record.files)
        DownloadFile(
          url: file.url,
          relativePath: file.path,
          bytes: file.bytes,
          sha256: file.sha256,
        ),
    ],
  );

  DownloadPlan withRecord(DownloadRecord record) =>
      DownloadPlan._(record: record, directory: directory, paths: paths);
}

@model
sealed class DownloadPlanResult {
  const DownloadPlanResult();
}

@model
final class DownloadPlanned extends DownloadPlanResult {
  const DownloadPlanned(this.plan);

  final DownloadPlan plan;
}

@model
final class DownloadPlanInvalid extends DownloadPlanResult {
  const DownloadPlanInvalid(this.reason);

  final InvalidDownload reason;
}
