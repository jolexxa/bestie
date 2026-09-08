import 'package:sandbox/src/lowering/effective_policy.dart';
import 'package:sandbox/src/lowering/glob.dart';
import 'package:sandbox/src/lowering/lowered_policy.dart';
import 'package:sandbox/src/lowering/lowering.dart';
import 'package:sandbox/src/lowering/lowering_outcome.dart';
import 'package:sandbox/src/lowering/resolved_spec.dart';

/// Lowering system for operating systems which support native deny-lists.
class NativeDenyLowering implements Lowering {
  /// Const so an adapter can compose it once.
  const NativeDenyLowering();

  @override
  LoweringOutcome lower(ResolvedSpec spec, GlobExpander globs) {
    final writable = spec.writableRoots.toSet();
    final grants = <Grant>[
      for (final path in spec.writableRoots) Grant(path, GrantAccess.readWrite),
      for (final path in spec.readableRoots)
        if (!writable.contains(path)) Grant(path, GrantAccess.read),
    ];
    final deniedPaths = _denyPaths(spec.denies, globs);

    return LoweringSucceeded(
      MaskedProgram(grants, [for (final path in deniedPaths) Deny(path)]),
      EffectivePolicy(
        readableRoots: spec.readableRoots,
        writableRoots: spec.writableRoots,
        deniedReads: deniedPaths,
      ),
    );
  }

  List<String> _denyPaths(
    List<ResolvedDeny> denies,
    GlobExpander globs,
  ) => [
    for (final deny in denies)
      if (deny.isGlob)
        ...globs.expand(base: deny.base, tail: deny.tail)
      else
        deny.path,
  ];
}
