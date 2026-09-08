import 'package:sandbox/src/sandbox_spec.dart';

/// A deny entry after symlink resolution.
///
/// [base] is canonical; [tail] is the glob remainder beneath it, empty for a
/// plain path. Kept separate so a report snapshot can expand [tail] under
/// [base] while the encoder ships [path] whole.
class ResolvedDeny {
  /// Wraps a resolved deny's [base], glob [tail], and whether it [isGlob].
  const ResolvedDeny({
    required this.base,
    required this.tail,
    required this.isGlob,
  });

  /// The canonical leading directory.
  final String base;

  /// The glob remainder beneath [base], empty for a plain path.
  final String tail;

  /// Whether this entry carried glob metacharacters.
  final bool isGlob;

  /// The full canonical path or glob pattern.
  String get path => tail.isEmpty ? base : '$base/$tail';
}

/// A [SandboxSpec] with every path canonicalized, ready to lower.
class ResolvedSpec {
  /// Wraps the canonical [readableRoots], [writableRoots], [denies], and the
  /// requested [network] tier.
  const ResolvedSpec({
    required this.readableRoots,
    required this.writableRoots,
    required this.denies,
    required this.network,
  });

  /// Trees the process may read.
  final List<String> readableRoots;

  /// Trees the process may write, workspace folded in.
  final List<String> writableRoots;

  /// The resolved deny entries.
  final List<ResolvedDeny> denies;

  /// The requested network tier.
  final NetworkTier network;
}
