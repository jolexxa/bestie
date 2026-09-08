import 'package:sandbox/src/lowering/effective_policy.dart';
import 'package:sandbox/src/lowering/glob.dart';
import 'package:sandbox/src/lowering/lowered_policy.dart';
import 'package:sandbox/src/lowering/lowering.dart';
import 'package:sandbox/src/lowering/lowering_outcome.dart';
import 'package:sandbox/src/lowering/resolved_spec.dart';

/// Lowering for backends with no native deny. Landlock is hierarchical
/// allow-only, so a deny is simulated by *enumeration*: rather than grant a
/// directory that contains a deny, grant each of its entries individually,
/// skip the denied one, and grant the directory itself list-only so `ls` still
/// works. The denied path's whole ancestor chain within a readable root is
/// decomposed this way, so a grant never recursively re-covers a deny.
class EnumeratedDenyLowering implements Lowering {
  /// Const so an adapter can compose it once.
  const EnumeratedDenyLowering();

  @override
  LoweringOutcome lower(ResolvedSpec spec, GlobExpander globs) {
    final deniedPaths = _snapshotDenies(spec.denies, globs);
    final writable = spec.writableRoots.toSet();

    final grants = <Grant>[
      for (final path in spec.writableRoots) Grant(path, GrantAccess.readWrite),
    ];

    for (final root in spec.readableRoots) {
      if (writable.contains(root)) continue;
      final under = deniedPaths.where((d) => _isUnder(d, root)).toList();
      if (under.isEmpty) {
        grants.add(Grant(root, GrantAccess.read));
        continue;
      }
      _decompose(root, under, deniedPaths, globs, grants);
    }

    return LoweringSucceeded(
      GrantProgram(grants),
      EffectivePolicy(
        readableRoots: spec.readableRoots,
        writableRoots: spec.writableRoots,
        deniedReads: deniedPaths.toList()..sort(),
      ),
    );
  }

  /// Resolves the deny list to concrete canonical paths — globs snapshotted
  /// against the filesystem, plain entries as-is (canonical from resolve).
  Set<String> _snapshotDenies(
    List<ResolvedDeny> denies,
    GlobExpander globs,
  ) => {
    for (final deny in denies)
      if (deny.isGlob)
        ...globs.expand(base: deny.base, tail: deny.tail)
      else
        deny.path,
  };

  /// Grants everything under [root] except the [under] denies, by breaking the
  /// denies' ancestor chain into list-only directories with per-entry read
  /// grants around the carve-outs.
  void _decompose(
    String root,
    List<String> under,
    Set<String> deniedPaths,
    GlobExpander globs,
    List<Grant> grants,
  ) {
    // The directories we must not grant wholesale: every ancestor of every
    // deny, from `root` down to the deny's parent.
    final decomposed = <String>{};
    for (final deny in under) {
      decomposed.addAll(_ancestorsFrom(root, _parentOf(deny)));
    }

    for (final dir in decomposed) {
      // List-only on the parent.
      grants.add(Grant(dir, GrantAccess.listDir));
      for (final child in globs.children(dir)) {
        if (decomposed.contains(child)) continue; // a deeper level handles it
        // Grant a child's subtree only when it is deny-free even through
        // symlinks — a link (or dir) whose canonical subtree holds a deny would
        // re-expose it, so skip it.
        final canonical = globs.canonicalize(child) ?? child;
        if (_subtreeHoldsDeny(canonical, deniedPaths)) continue;
        grants.add(Grant(child, GrantAccess.read));
      }
    }
  }

  /// Whether any denied path lies at or beneath [path] — i.e. granting [path]
  /// recursively would re-expose a deny.
  bool _subtreeHoldsDeny(String path, Set<String> deniedPaths) =>
      deniedPaths.any((deny) => deny == path || _isUnder(deny, path));
}

/// Whether [path] is [root] itself or lies beneath it. Paths are canonical, so
/// a prefix match on a directory boundary is exact.
bool _isUnder(String path, String root) =>
    path == root || path.startsWith(root == '/' ? '/' : '$root/');

/// The parent directory of [path]; `/` for a top-level entry.
String _parentOf(String path) {
  final slash = path.lastIndexOf('/');
  if (slash <= 0) return '/';
  return path.substring(0, slash);
}

/// The chain of directories from [root] down to [dir] inclusive, e.g.
/// `(/home/joanna, /home/joanna/.config)` — the levels we decompose.
Iterable<String> _ancestorsFrom(String root, String dir) {
  final chain = <String>[];
  var current = dir;
  while (true) {
    chain.add(current);
    if (current == root || current == '/') break;
    current = _parentOf(current);
  }
  return chain.reversed;
}
