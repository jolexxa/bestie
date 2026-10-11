import 'package:dart_mappable/dart_mappable.dart';

part 'engine_sampling.mapper.dart';

/// Token sampling parameters applied at inference time.
///
/// Any field left null falls back to the matching `default…` constant, which
/// mirrors llama.cpp's own `common_params_sampling` defaults.
@MappableClass()
class EngineSampling with EngineSamplingMappable {
  /// Creates a set of sampling options.
  const EngineSampling({
    this.seed,
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

  /// The [topK] used when it is left null.
  static const defaultTopK = 40;

  /// The [topP] used when it is left null.
  static const defaultTopP = 0.95;

  /// The [minP] used when it is left null.
  static const defaultMinP = 0.05;

  /// The [temperature] used when it is left null.
  static const defaultTemperature = 0.8;

  /// The [typicalP] used when it is left null.
  static const defaultTypicalP = 1.0;

  /// The [penaltyRepeat] used when it is left null.
  static const defaultPenaltyRepeat = 1.0;

  /// The [penaltyLastN] used when it is left null.
  static const defaultPenaltyLastN = 64;

  /// The [penaltyFreq] used when it is left null.
  static const defaultPenaltyFreq = 0.0;

  /// The [penaltyPresent] used when it is left null.
  static const defaultPenaltyPresent = 0.0;

  /// RNG seed for reproducible sampling. Null or `0` draws a fresh random
  /// seed for every sampler.
  final int? seed;

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
