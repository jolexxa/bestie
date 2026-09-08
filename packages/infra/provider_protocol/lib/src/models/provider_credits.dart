import 'package:meta/meta.dart';

/// The span of time a provider's reported spend covers.
enum SpendWindow { lifetime, monthToDate }

/// What a provider reports about money: spend over [window], and the prepaid
/// balance still left when the provider keeps one.
@immutable
final class ProviderCredits {
  const ProviderCredits({
    required this.spent,
    required this.window,
    this.remaining,
  });

  /// Spend in the provider's currency units across [window].
  final double spent;

  final SpendWindow window;

  /// Balance left to spend; null when the provider does not report one.
  final double? remaining;

  /// This balance after a charge of [cost].
  ProviderCredits charged(double cost) => ProviderCredits(
    spent: spent + cost,
    window: window,
    remaining: switch (remaining) {
      null => null,
      final remaining => remaining - cost,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is ProviderCredits &&
      other.spent == spent &&
      other.window == window &&
      other.remaining == remaining;

  @override
  int get hashCode => Object.hash(spent, window, remaining);

  @override
  String toString() =>
      'ProviderCredits(spent: $spent, window: ${window.name}, '
      'remaining: $remaining)';
}
