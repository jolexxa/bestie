import 'package:meta/meta.dart';

/// What the provider knows about the API key in use.
@immutable
final class ProviderKeyInfo {
  const ProviderKeyInfo({
    required this.label,
    required this.usage,
    required this.isFreeTier,
    this.limit,
    this.limitRemaining,
  });

  final String label;

  final double usage;

  final bool isFreeTier;

  final double? limit;

  final double? limitRemaining;

  @override
  bool operator ==(Object other) =>
      other is ProviderKeyInfo &&
      other.label == label &&
      other.usage == usage &&
      other.isFreeTier == isFreeTier &&
      other.limit == limit &&
      other.limitRemaining == limitRemaining;

  @override
  int get hashCode =>
      Object.hash(label, usage, isFreeTier, limit, limitRemaining);

  @override
  String toString() => 'ProviderKeyInfo($label, used: $usage)';
}
