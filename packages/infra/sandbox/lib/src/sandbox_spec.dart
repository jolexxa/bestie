import 'package:dart_mappable/dart_mappable.dart';

part 'sandbox_spec.mapper.dart';

/// How much of the network a confined process may reach.
@MappableEnum()
enum NetworkTier {
  /// No network at all.
  none,

  /// Loopback (localhost access) only.
  local,

  /// Unrestricted.
  all,
}

/// What a caller asks a sandbox to confine.
///
/// Reads are broad minus [deniedReads]; writes are narrow and allow-listed.
@MappableClass()
class SandboxSpec with SandboxSpecMappable {
  /// Confines a process to [workspaceRoot] plus whatever else is named here.
  const SandboxSpec({
    required this.workspaceRoot,
    this.readableRoots = const [],
    this.deniedReads = const [],
    this.writableRoots = const [],
    this.network = NetworkTier.all,
  });

  /// The directory the confined process works in.
  final String workspaceRoot;

  /// Trees the process may read.
  final List<String> readableRoots;

  /// Carve-outs of [readableRoots] it may not, as paths or globs.
  final List<String> deniedReads;

  /// Trees the process may write.
  final List<String> writableRoots;

  /// The network tier requested.
  final NetworkTier network;
}
