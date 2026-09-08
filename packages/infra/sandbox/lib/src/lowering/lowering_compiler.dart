import 'package:file/file.dart';
import 'package:sandbox/src/lowering/glob.dart';
import 'package:sandbox/src/lowering/lowering.dart';
import 'package:sandbox/src/lowering/lowering_outcome.dart';
import 'package:sandbox/src/lowering/resolve.dart';
import 'package:sandbox/src/sandbox_spec.dart';

/// Runs the shared resolve pass, then a per-backend [Lowering] strategy.
class LoweringCompiler {
  /// Composes a [strategy] over a [fs].
  LoweringCompiler(this.strategy, FileSystem fs)
    : _resolver = SpecResolver(fs),
      _globs = GlobExpander(fs);

  /// The per-backend strategy.
  final Lowering strategy;

  final SpecResolver _resolver;
  final GlobExpander _globs;

  /// Lowers [spec] to a policy and report, or a failure.
  LoweringOutcome compile(SandboxSpec spec) =>
      strategy.lower(_resolver.resolve(spec), _globs);
}
