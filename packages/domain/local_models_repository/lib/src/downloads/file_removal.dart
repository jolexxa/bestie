import 'package:intentions/intentions.dart';

/// What deleting a download's files came to.
@model
sealed class FileRemoval {
  const FileRemoval();
}

@model
final class FilesRemoved extends FileRemoval {
  const FilesRemoved(this.freedBytes);

  final int freedBytes;
}

/// [path] is still there; files before it may be gone.
@model
final class FileRemovalFailed extends FileRemoval {
  const FileRemovalFailed({required this.path, required this.error});

  final String path;

  final String error;
}
