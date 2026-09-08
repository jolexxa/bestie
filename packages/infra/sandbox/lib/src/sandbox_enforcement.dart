import 'package:dart_mappable/dart_mappable.dart';
import 'package:sandbox/src/sandbox_spec.dart';

part 'sandbox_enforcement.mapper.dart';

/// A restriction a sandbox can actually hold.
@MappableEnum()
enum SandboxCapability {
  /// Reads are confined.
  filesystemRead,

  /// Writes are confined.
  filesystemWrite,
}

/// What became of the requested network tier.
@MappableClass(discriminatorKey: 'type')
sealed class NetworkEnforcement with NetworkEnforcementMappable {
  const NetworkEnforcement();
}

/// The network is confined to [tier].
@MappableClass(discriminatorValue: 'confined')
final class NetworkConfined extends NetworkEnforcement
    with NetworkConfinedMappable {
  /// Confined to [tier].
  const NetworkConfined(this.tier);

  /// The tier in force.
  final NetworkTier tier;
}

/// The tier was requested but cannot be enforced on this machine.
@MappableClass(discriminatorValue: 'unconfinable')
final class NetworkIneligibleForConfinement extends NetworkEnforcement
    with NetworkIneligibleForConfinementMappable {
  /// [requested] could not be enforced, for [reason].
  const NetworkIneligibleForConfinement(this.requested, this.reason);

  /// The tier that was asked for.
  final NetworkTier requested;

  /// Why this machine cannot provide it.
  final String reason;
}

/// The tier partly stuck: some of what it grants is in force, but a named part
/// is not. The honest report for Windows `all` with Developer Mode off, where
/// the internet is reachable (`InternetClient`) but loopback is not (the
/// exemption needs Developer Mode).
@MappableClass(discriminatorValue: 'partial')
final class NetworkPartiallyConfined extends NetworkEnforcement
    with NetworkPartiallyConfinedMappable {
  /// [requested] mostly stuck, but [unavailable] could not be provided, for
  /// [reason].
  const NetworkPartiallyConfined(
    this.requested,
    this.unavailable,
    this.reason,
  );

  /// The tier that was asked for.
  final NetworkTier requested;

  /// The part that could not be provided, e.g. `'loopback'`.
  final String unavailable;

  /// Why that part is missing.
  final String reason;
}

/// What a sandbox actually enforces, capability-shaped rather than
/// backend-shaped.
@MappableClass()
class SandboxEnforcement with SandboxEnforcementMappable {
  /// Reports the restrictions that stuck.
  const SandboxEnforcement({
    required this.enforced,
    required this.network,
    required this.backend,
    this.readableRoots = const [],
    this.deniedReads = const [],
    this.writableRoots = const [],
  });

  /// The restrictions in force. Empty means nothing is confined.
  final Set<SandboxCapability> enforced;

  /// Trees the process may read.
  final List<String> readableRoots;

  /// Carve-outs it may not, after glob expansion.
  final List<String> deniedReads;

  /// Trees the process may write.
  final List<String> writableRoots;

  /// What became of the requested network tier.
  final NetworkEnforcement network;

  /// The mechanism behind this, for display only.
  final String backend;
}
