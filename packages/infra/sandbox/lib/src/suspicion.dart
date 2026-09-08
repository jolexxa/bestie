import 'package:dart_mappable/dart_mappable.dart';

part 'suspicion.mapper.dart';

/// A restriction a sandbox can hold, as a possible cause of a failure.
@MappableEnum()
enum SandboxDimension {
  /// A read was refused.
  filesystemRead,

  /// A write was refused.
  filesystemWrite,

  /// The network was out of reach.
  network,
}

/// One live restriction that could explain a failure.
@MappableClass()
class SandboxSuspicion with SandboxSuspicionMappable {
  /// A suspicion about [dimension], supported by [evidence].
  const SandboxSuspicion({required this.dimension, this.evidence = const []});

  /// The restriction under suspicion.
  final SandboxDimension dimension;

  /// Output lines consistent with it, possibly none.
  final List<String> evidence;
}
