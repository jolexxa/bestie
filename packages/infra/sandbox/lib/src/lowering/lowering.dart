import 'package:sandbox/src/lowering/glob.dart';
import 'package:sandbox/src/lowering/lowering_outcome.dart';
import 'package:sandbox/src/lowering/resolved_spec.dart';

/// A per-backend lowering strategy: everything after the shared resolve pass.
///
/// macOS expresses globs and denies natively (`NativeDenyLowering`); Landlock
/// and AppContainer can express neither and simulate them
/// (`EnumeratedDenyLowering`, landing with the Linux/Windows adapters).
abstract interface class Lowering {
  /// Lowers a canonical [spec], using [globs] for any snapshotting it needs.
  LoweringOutcome lower(ResolvedSpec spec, GlobExpander globs);
}
