import 'package:meta/meta.dart';

/// The sampling knobs every OpenAI-compatible server understands.
@immutable
final class InferenceSampling {
  const InferenceSampling({
    this.temperature,
    this.topP,
    this.frequencyPenalty,
    this.presencePenalty,
    this.seed,
    this.maxOutputTokens,
  });

  final double? temperature;

  final double? topP;

  final double? frequencyPenalty;

  final double? presencePenalty;

  final int? seed;

  final int? maxOutputTokens;

  InferenceSampling copyWith({int? maxOutputTokens}) => InferenceSampling(
    temperature: temperature,
    topP: topP,
    frequencyPenalty: frequencyPenalty,
    presencePenalty: presencePenalty,
    seed: seed,
    maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
  );

  @override
  bool operator ==(Object other) =>
      other is InferenceSampling &&
      other.temperature == temperature &&
      other.topP == topP &&
      other.frequencyPenalty == frequencyPenalty &&
      other.presencePenalty == presencePenalty &&
      other.seed == seed &&
      other.maxOutputTokens == maxOutputTokens;

  @override
  int get hashCode => Object.hash(
    temperature,
    topP,
    frequencyPenalty,
    presencePenalty,
    seed,
    maxOutputTokens,
  );
}
