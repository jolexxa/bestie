import 'package:file/file.dart';
import 'package:sandbox/src/lowering/glob.dart';
import 'package:sandbox/src/lowering/resolved_spec.dart';
import 'package:sandbox/src/sandbox_spec.dart';

/// Canonicalizes a [SandboxSpec]'s paths against an injected [FileSystem].
class SpecResolver {
  /// Resolves symlinks through the filesystem.
  const SpecResolver(this._fs);

  final FileSystem _fs;

  /// Canonicalizes every path in [spec], best-effort.
  ///
  /// A path that will not canonicalize is kept as given: an allow root is
  /// rejected by the kernel at apply time if bogus, and a deny on a missing
  /// path is a subpath rule that costs nothing until something appears there.
  ResolvedSpec resolve(SandboxSpec spec) => ResolvedSpec(
    readableRoots: _canonicalizeAll(spec.readableRoots),
    writableRoots: _canonicalizeAll([
      spec.workspaceRoot,
      ...spec.writableRoots,
    ]),
    denies: [for (final entry in spec.deniedReads) _resolveDeny(entry)],
    network: spec.network,
  );

  ResolvedDeny _resolveDeny(String entry) {
    if (!isGlob(entry)) {
      return ResolvedDeny(
        base: _canonicalize(entry) ?? entry,
        tail: '',
        isGlob: false,
      );
    }
    final split = splitGlob(entry);
    return ResolvedDeny(
      base: _canonicalize(split.base) ?? split.base,
      tail: split.tail,
      isGlob: true,
    );
  }

  List<String> _canonicalizeAll(Iterable<String> paths) {
    final seen = <String>{};
    final result = <String>[];
    for (final path in paths) {
      final canonical = _canonicalize(path);
      // Grant the resolved target *and* the original when a symlink made them
      // differ: the kernel needs the symlink node itself granted to traverse
      // it, so canonicalizing alone would drop access reached through the link
      // (macOS `/var`→`/private/var`, `/etc`→`/private/etc`).
      for (final grant in [canonical ?? path, path]) {
        if (seen.add(grant)) result.add(grant);
      }
    }
    return result;
  }

  String? _canonicalize(String path) {
    try {
      return _fs.file(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return null;
    }
  }
}
