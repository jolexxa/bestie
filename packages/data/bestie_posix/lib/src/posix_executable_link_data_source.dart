import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:intentions/intentions.dart';

/// POSIX implementation of [ExecutableLinkDataSource], shared by macOS and
/// Linux. Dispatch names are symlinks to the coreutils multicall — the SDK's
/// own link API, so no native binding is needed the way Windows hardlinks are.
@dataSource
class PosixExecutableLinkDataSource implements ExecutableLinkDataSource {
  /// [fileSystem] defaults to the host filesystem; pass a `MemoryFileSystem`
  /// to substitute a double.
  PosixExecutableLinkDataSource({FileSystem? fileSystem})
    : _fs = fileSystem ?? const LocalFileSystem();

  final FileSystem _fs;

  @override
  ExecutableLinkResult link({
    required String linkPath,
    required String targetPath,
  }) {
    try {
      _fs.link(linkPath).createSync(targetPath);
      return const ExecutableLinkCreated();
    } on FileSystemException catch (error) {
      return ExecutableLinkFailed(error.message);
    }
  }
}
