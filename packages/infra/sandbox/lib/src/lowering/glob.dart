import 'package:file/file.dart';

const _globChars = {'*', '?', '[', ']'};

/// Whether [pattern] carries any glob metacharacter.
bool isGlob(String pattern) => pattern.split('').any(_globChars.contains);

/// A glob pattern split into its non-glob [base] directory and the glob
/// [tail] beneath it.
class GlobSplit {
  /// Wraps the non-glob [base] and the glob [tail].
  const GlobSplit(this.base, this.tail);

  /// The longest non-glob leading directory.
  final String base;

  /// The glob remainder beneath [base], empty for a plain pattern.
  final String tail;
}

/// Splits [pattern] into its longest non-glob leading directory (`base`) and
/// the glob remainder beneath it (`tail`). A plain pattern is all base.
GlobSplit splitGlob(String pattern) {
  final segments = pattern.split('/');
  final base = <String>[];
  var index = 0;
  while (index < segments.length && !isGlob(segments[index])) {
    base.add(segments[index]);
    index++;
  }
  final tail = segments.sublist(index).join('/');
  final joined = base.join('/');
  return GlobSplit(joined.isEmpty ? '/' : joined, tail);
}

/// Expands glob tails against an injected [FileSystem].
class GlobExpander {
  /// Walks the filesystem to enumerate matches.
  const GlobExpander(this._fs);

  final FileSystem _fs;

  /// Expands the glob [tail] under canonical [base], returning every concrete
  /// matching path. Enforcement backends deny exactly this set, so it must be
  /// complete.
  List<String> expand({required String base, required String tail}) {
    if (tail.isEmpty) return [base];
    final matches = <String>[];
    _walk(base, tail.split('/'), matches);
    return matches;
  }

  void _walk(String dir, List<String> segments, List<String> matches) {
    final segment = segments.first;
    final rest = segments.sublist(1);

    if (segment == '**') {
      _walkDeep(dir, rest, matches);
      return;
    }

    final children = _readDir(dir);
    if (children == null) return;
    final matcher = _segmentMatcher(segment);
    for (final child in children) {
      if (!matcher.hasMatch(_basename(child))) continue;
      if (rest.isEmpty) {
        matches.add(child);
      } else {
        _walk(child, rest, matches);
      }
    }
  }

  void _walkDeep(String dir, List<String> rest, List<String> matches) {
    if (rest.isEmpty) {
      matches.add(dir);
    } else {
      _walk(dir, rest, matches);
    }
    final children = _readDir(dir);
    if (children == null) return;
    for (final child in children) {
      _walkDeep(child, rest, matches);
    }
  }

  /// Lists the immediate children of [path] as absolute paths, or an empty list
  /// when [path] is not a readable directory.
  List<String> children(String path) => _readDir(path) ?? const [];

  /// Fully resolves symlinks in [path]; null if it does not exist or the chain
  /// breaks.
  String? canonicalize(String path) {
    try {
      return _fs.file(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return null;
    }
  }

  List<String>? _readDir(String path) {
    if (!_fs.isDirectorySync(path)) return null;
    try {
      return _fs
          .directory(path)
          .listSync(followLinks: false)
          .map((entity) => entity.path)
          .toList();
    } on FileSystemException {
      return null;
    }
  }
}

String _basename(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}

RegExp _segmentMatcher(String segment) {
  final buffer = StringBuffer('^');
  for (final rune in segment.split('')) {
    buffer.write(switch (rune) {
      '*' => '[^/]*',
      '?' => '[^/]',
      '[' || ']' => rune,
      _ => RegExp.escape(rune),
    });
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}
