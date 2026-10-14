import 'package:intentions/intentions.dart';

/// A quick estimate of whether a model file fits in the memory available to
/// run it. The exact fit is measured when the model loads; this only compares
/// sizes, before anything is downloaded.
@model
enum ModelFit {
  /// Leaves room for a working context and subagents.
  fits,

  /// Loads, with little room left for context.
  tight,

  /// Will not load, or barely loads with a uselessly small context.
  tooBig;

  /// The largest share of available memory the weights may take and still
  /// leave a comfortable context: KV cache and compute buffers for a 32k
  /// context and a few subagents take roughly the remaining 40%.
  static const fitsShare = 0.60;

  /// The largest share that still loads with a small context.
  static const tightShare = 0.85;

  static ModelFit estimate({
    required int modelBytes,
    required int availableBytes,
  }) => switch (modelBytes / availableBytes) {
    <= fitsShare => fits,
    <= tightShare => tight,
    _ => tooBig,
  };
}
