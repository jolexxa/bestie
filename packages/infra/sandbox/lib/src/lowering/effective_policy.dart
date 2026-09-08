import 'package:dart_mappable/dart_mappable.dart';

part 'effective_policy.mapper.dart';

/// What a lowering actually resolved to, for a human to read.
///
/// [deniedReads] is a concrete, acquire-time snapshot on every platform — the
/// honest "as of now" set, not a promise of future coverage.
@MappableClass()
class EffectivePolicy with EffectivePolicyMappable {
  /// Wraps the resolved read/write roots and the concrete denied reads.
  const EffectivePolicy({
    this.readableRoots = const [],
    this.writableRoots = const [],
    this.deniedReads = const [],
  });

  /// Trees the process may read.
  final List<String> readableRoots;

  /// Trees the process may write.
  final List<String> writableRoots;

  /// The concrete, acquire-time snapshot of denied reads.
  final List<String> deniedReads;
}
