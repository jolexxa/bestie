import 'package:intentions/intentions.dart';

/// Sampling defaults the model author recommends under `general.sampling.*`.
@model
final class GgufSampling {
  const GgufSampling({
    this.temperature,
    this.topK,
    this.topP,
    this.minP,
    this.penaltyLastN,
    this.penaltyRepeat,
  });

  final double? temperature;
  final int? topK;
  final double? topP;
  final double? minP;
  final int? penaltyLastN;
  final double? penaltyRepeat;
}
