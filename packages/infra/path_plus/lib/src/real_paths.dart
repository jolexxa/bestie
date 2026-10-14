import 'package:file/file.dart';

/// Resolves symlinks through an injected [FileSystem].
final class RealPaths {
  const RealPaths(this._fs);

  final FileSystem _fs;

  /// [path] with every symlink resolved, or null when it does not exist or
  /// the chain breaks.
  String? canonicalize(String path) {
    try {
      return _fs.file(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return null;
    }
  }

  /// [absolutePath] resolved as far as the filesystem goes: its deepest
  /// existing ancestor is canonicalized and the rest is kept as written.
  ///
  /// [absolutePath] should not be normalized beforehand, so that `..` after a
  /// symlink means what it means to the kernel.
  String resolve(String absolutePath) {
    final path = _fs.path;
    final unresolved = <String>[];
    var candidate = absolutePath;
    while (true) {
      final canonical = canonicalize(candidate);
      if (canonical != null) {
        return path.normalize(path.joinAll([canonical, ...unresolved]));
      }
      final parent = path.dirname(candidate);
      if (parent == candidate) return path.normalize(absolutePath);
      unresolved.insert(0, path.basename(candidate));
      candidate = parent;
    }
  }
}
