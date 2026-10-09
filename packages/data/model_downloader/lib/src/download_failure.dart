import 'package:intentions/intentions.dart';

/// Why a download stopped with an error.
@model
sealed class DownloadFailure {
  const DownloadFailure();

  /// A sentence fit to show the person who started the download.
  String get message;
}

/// The server answered with a status that is not the file, e.g. 401 when a
/// token is missing, 403 for a gated repo, 404, or 416 when the remote file
/// no longer has the size that was asked for.
@model
final class DownloadHttpStatus extends DownloadFailure {
  const DownloadHttpStatus(this.statusCode);

  final int statusCode;

  @override
  String get message => switch (statusCode) {
    401 => 'The server requires authentication (HTTP 401).',
    403 => 'Access to the file was denied (HTTP 403).',
    404 => 'The file was not found (HTTP 404).',
    416 => 'The server rejected the requested byte range (HTTP 416).',
    _ => 'The server answered with HTTP $statusCode.',
  };
}

/// The connection failed, stalled past the idle timeout, or was refused.
@model
final class DownloadNetworkError extends DownloadFailure {
  const DownloadNetworkError(this.detail);

  final String detail;

  @override
  String get message => 'Network error: $detail';
}

/// The disk has no room left for the file.
@model
final class DownloadDiskFull extends DownloadFailure {
  const DownloadDiskFull();

  @override
  String get message => 'There is not enough disk space for the file.';
}

/// Reading or writing the file failed for a reason other than space.
@model
final class DownloadIoError extends DownloadFailure {
  const DownloadIoError(this.detail);

  final String detail;

  @override
  String get message => 'Could not write the file: $detail';
}

/// A response body ended before, or ran past, the bytes it was asked for.
@model
final class DownloadTruncated extends DownloadFailure {
  const DownloadTruncated({
    required this.expectedBytes,
    required this.receivedBytes,
  });

  final int expectedBytes;
  final int receivedBytes;

  @override
  String get message =>
      'The server sent $receivedBytes bytes where $expectedBytes were '
      'expected.';
}

/// A file's relative path would place it outside the job's directory.
@model
final class DownloadUnsafePath extends DownloadFailure {
  const DownloadUnsafePath({
    required this.relativePath,
    required this.directory,
  });

  final String relativePath;
  final String directory;

  @override
  String get message => '$relativePath would be written outside $directory.';
}

/// The background download worker could not start or crashed.
@model
final class DownloadWorkerError extends DownloadFailure {
  const DownloadWorkerError(this.detail);

  final String detail;

  @override
  String get message => 'The download worker failed: $detail';
}
