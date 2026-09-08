import 'package:path/path.dart' as p;

/// The proper ancestors of each of [roots], up to its drive or filesystem
/// root, minus any covered by a root or under [systemRoots]. Top-down per
/// root, each directory once.
List<String> unlistedAncestorsOf({
  required Iterable<String> roots,
  required p.Context context,
  Iterable<String> systemRoots = const [],
}) {
  final covering = [...roots, ...systemRoots];
  bool covered(String directory) => covering.any(
    (root) =>
        context.equals(root, directory) || context.isWithin(root, directory),
  );

  final seen = <String>{};
  final ancestors = <String>[];
  for (final root in roots) {
    final chain = <String>[];
    var directory = context.dirname(root);
    while (!context.equals(directory, context.dirname(directory))) {
      chain.add(directory);
      directory = context.dirname(directory);
    }
    chain.add(directory);
    for (final ancestor in chain.reversed) {
      if (covered(ancestor)) continue;
      if (seen.add(context.canonicalize(ancestor))) ancestors.add(ancestor);
    }
  }
  return ancestors;
}
