import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;

/// One file to fetch and where it goes, relative to the job's directory.
@model
final class DownloadFile {
  const DownloadFile({
    required this.url,
    required this.relativePath,
    required this.bytes,
    this.sha256,
  });

  final String url;

  final String relativePath;

  final int bytes;

  /// The expected lowercase hex digest, checked once the file is on disk.
  final String? sha256;
}

/// A set of files downloaded together into [directory], one after another.
@model
final class DownloadJob {
  const DownloadJob({required this.directory, required this.files});

  final String directory;

  final List<DownloadFile> files;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.bytes);

  String targetPathFor(DownloadFile file) =>
      p.normalize(p.join(directory, file.relativePath));

  /// Whether [file] would land outside [directory], e.g. via `..`.
  bool escapes(DownloadFile file) =>
      !p.isWithin(directory, targetPathFor(file));
}
