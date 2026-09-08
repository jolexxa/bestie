import 'package:agent_provider_protocol/src/runtime/models/agent_handle.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'context_pool_snapshot.mapper.dart';

/// One lease's footprint in the shared KV pool at a single instant.
@MappableClass()
final class PoolLeaseOccupancy with PoolLeaseOccupancyMappable {
  const PoolLeaseOccupancy({
    required this.handle,
    required this.residentTokens,
    required this.claimTokens,
  });

  /// The agent holding this lease. `handle.kind` distinguishes the primary from
  /// a subagent.
  final AgentHandle handle;

  /// Tokens currently resident in this lease's sequence.
  final int residentTokens;

  /// KV cells this lease claims from the pool. Zero for the primary (it draws
  /// from whatever the pool has left after subagent claims).
  final int claimTokens;
}

/// A whole-pool occupancy reading. Emitted by the runtime whenever the pool
/// changes (reserve, release, or a decode that moves residency), so a consumer
/// reads the current truth rather than reconstructing it from a per-agent
/// event stream.
@MappableClass()
final class ContextPoolSnapshot with ContextPoolSnapshotMappable {
  const ContextPoolSnapshot({
    required this.contextSize,
    required this.reservedClaims,
    required this.leases,
  });

  /// Total shared KV pool size.
  final int contextSize;

  /// Sum of active subagent claims — the cells loaned out of the primary's
  /// entitlement.
  final int reservedClaims;

  /// Per-lease occupancy for every active agent.
  final List<PoolLeaseOccupancy> leases;
}
