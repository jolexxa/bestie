import 'package:crypto/crypto.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:model_downloader/src/model_downloader.dart';

/// Streams a file through sha256.
@PartOf(ModelDownloader)
class FileHasher {
  const FileHasher();

  /// The lowercase hex digest of [file]'s contents. Reading stops at the
  /// next chunk once [cancellation] is requested.
  Future<FileHashResult> sha256Of(
    File file, {
    required IsolateCancellationToken cancellation,
  }) async {
    final digest = await sha256
        .bind(
          file.openRead().takeWhile(
            (_) => !cancellation.isCancellationRequested,
          ),
        )
        .single;
    return cancellation.isCancellationRequested
        ? const FileHashCancelled()
        : FileHashed('$digest');
  }
}

@PartOf(ModelDownloader)
sealed class FileHashResult {
  const FileHashResult();
}

@PartOf(ModelDownloader)
final class FileHashed extends FileHashResult {
  const FileHashed(this.digest);

  /// The lowercase hex digest.
  final String digest;
}

/// Hashing stopped part way because the download was cancelled.
@PartOf(ModelDownloader)
final class FileHashCancelled extends FileHashResult {
  const FileHashCancelled();
}
