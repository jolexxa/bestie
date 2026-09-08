import 'package:dart_mappable/dart_mappable.dart';

part 'sampling_options.mapper.dart';

/// Token sampling parameters applied at inference time.
///
/// Any field left null falls back to the provider's own default.
@MappableClass()
class SamplingOptions with SamplingOptionsMappable {
  /// Creates a set of sampling options.
  const SamplingOptions({
    required this.seed,
    this.topK,
    this.topP,
    this.minP,
    this.temperature,
    this.typicalP,
    this.penaltyRepeat,
    this.penaltyLastN,
    this.penaltyFreq,
    this.penaltyPresent,
  });

  /// RNG seed for reproducible sampling. Use `0` for nondeterministic.
  final int seed;

  /// Keep only the [topK] highest-probability tokens before sampling.
  final int? topK;

  /// Nucleus sampling: keep the smallest set of tokens whose cumulative
  /// probability is at least [topP].
  final double? topP;

  /// Drop tokens whose probability is below [minP] times the top token's
  /// probability.
  final double? minP;

  /// Softmax temperature. Higher values flatten the distribution
  /// (more random); lower values sharpen it (more deterministic).
  final double? temperature;

  /// Locally-typical sampling threshold. Keeps tokens whose information
  /// content is close to the distribution's expected entropy.
  final double? typicalP;

  /// Multiplicative penalty applied to tokens that appeared in the last
  /// [penaltyLastN] tokens. `1.0` disables.
  final double? penaltyRepeat;

  /// Window size, in recent tokens, over which repetition/frequency
  /// penalties are computed.
  final int? penaltyLastN;

  /// Additive penalty proportional to how often a token has occurred in
  /// the recent window.
  final double? penaltyFreq;

  /// Additive penalty applied once to any token that has occurred in the
  /// recent window, regardless of count.
  final double? penaltyPresent;
}
