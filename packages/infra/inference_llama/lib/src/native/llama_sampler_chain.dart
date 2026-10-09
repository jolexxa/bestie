import 'dart:ffi';

import 'package:inference/inference.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

final class LlamaSamplerChain {
  LlamaSamplerChain(this._bindings, this._sampler);

  factory LlamaSamplerChain.build(
    LlamaCppBindings bindings,
    EngineSampling options, {
    required int vocabularySize,
  }) {
    final chainParams = bindings.llama_sampler_chain_default_params();
    final chain = bindings.llama_sampler_chain_init(chainParams);

    final topK = options.topK ?? EngineSampling.defaultTopK;
    final topP = options.topP ?? EngineSampling.defaultTopP;
    final minP = options.minP ?? EngineSampling.defaultMinP;
    final temp = options.temperature ?? EngineSampling.defaultTemperature;
    final typicalP = options.typicalP ?? EngineSampling.defaultTypicalP;
    final penaltyRepeat =
        options.penaltyRepeat ?? EngineSampling.defaultPenaltyRepeat;
    final penaltyLastN =
        options.penaltyLastN ?? EngineSampling.defaultPenaltyLastN;
    final penaltyFreq =
        options.penaltyFreq ?? EngineSampling.defaultPenaltyFreq;
    final penaltyPresent =
        options.penaltyPresent ?? EngineSampling.defaultPenaltyPresent;

    if (topK > 0) {
      bindings.llama_sampler_chain_add(
        chain,
        bindings.llama_sampler_init_top_k(topK),
      );
    }
    if (topP > 0 && topP < 1.0) {
      bindings.llama_sampler_chain_add(
        chain,
        bindings.llama_sampler_init_top_p(topP, 1),
      );
    }
    if (minP > 0) {
      bindings.llama_sampler_chain_add(
        chain,
        bindings.llama_sampler_init_min_p(minP, 1),
      );
    }
    if (typicalP > 0 && typicalP < 1.0) {
      bindings.llama_sampler_chain_add(
        chain,
        bindings.llama_sampler_init_typical(typicalP, 1),
      );
    }
    if (penaltyRepeat > 1.0 || penaltyFreq > 0 || penaltyPresent > 0) {
      bindings.llama_sampler_chain_add(
        chain,
        bindings.llama_sampler_init_penalties(
          vocabularySize,
          penaltyLastN,
          penaltyRepeat,
          penaltyFreq,
          penaltyPresent,
        ),
      );
    }
    if (temp <= 0) {
      bindings.llama_sampler_chain_add(
        chain,
        bindings.llama_sampler_init_greedy(),
      );
    } else {
      bindings
        ..llama_sampler_chain_add(chain, bindings.llama_sampler_init_temp(temp))
        ..llama_sampler_chain_add(
          chain,
          bindings.llama_sampler_init_dist(nativeSeed(options.seed)),
        );
    }

    return LlamaSamplerChain(bindings, chain);
  }

  /// The seed llama.cpp's distribution sampler takes for [seed]: null and
  /// `0` both ask for a random seed.
  static int nativeSeed(int? seed) =>
      seed == null || seed == 0 ? LLAMA_DEFAULT_SEED : seed;

  final LlamaCppBindings _bindings;
  final Pointer<llama_sampler> _sampler;

  int sampleAt(Pointer<llama_context> ctx, int idx) {
    return _bindings.llama_sampler_sample(_sampler, ctx, idx);
  }

  LlamaSamplerChain clone() {
    return LlamaSamplerChain(
      _bindings,
      _bindings.llama_sampler_clone(_sampler),
    );
  }

  void reset() {
    _bindings.llama_sampler_reset(_sampler);
  }

  void accept(int token) {
    _bindings.llama_sampler_accept(_sampler, token);
  }

  void dispose() {
    _bindings.llama_sampler_free(_sampler);
  }
}
