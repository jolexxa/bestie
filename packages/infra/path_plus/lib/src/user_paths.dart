import 'package:path/path.dart' as p;

/// Paths as this user writes them on this operating system.
final class UserPaths {
  const UserPaths({required this.homeDir, required p.Context context})
    : _context = context;

  final String homeDir;

  final p.Context _context;

  /// [path] with a leading `~` replaced by [homeDir]; anything else unchanged.
  String expandHome(String path) => switch (path) {
    '~' => homeDir,
    _ when path.startsWith('~/') || path.startsWith(r'~\') => _context.join(
      homeDir,
      path.substring(2),
    ),
    _ => path,
  };

  /// [path] as the user knows it: [homeDir] written as `~`.
  String shortenHome(String path) {
    if (isHome(path)) return '~';
    return _context.isWithin(homeDir, path)
        ? _context.join('~', _context.relative(path, from: homeDir))
        : path;
  }

  /// [relative], written with `/`, as a path under [homeDir].
  String underHome(String relative) =>
      _context.joinAll([homeDir, ...relative.split('/')]);

  bool isAbsolute(String path) => _context.isAbsolute(path);

  String normalize(String path) => _context.normalize(path);

  /// [path] as an absolute, normalized path: `~` expanded, and a relative
  /// path taken from [from].
  String resolve(String path, {required String from}) {
    final expanded = expandHome(path);
    return normalize(
      isAbsolute(expanded) ? expanded : _context.join(from, expanded),
    );
  }

  /// Whether [root] is [path] or an ancestor of it.
  bool covers(String root, String path) =>
      _context.equals(root, path) || _context.isWithin(root, path);

  bool isFilesystemRoot(String path) =>
      _context.equals(_context.rootPrefix(path), path);

  bool isHome(String path) => _context.equals(homeDir, path);
}
