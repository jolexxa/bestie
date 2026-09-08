import 'dart:convert';

import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';

/// One parsed models.dev `api.json`: providers keyed by id, each holding
/// models keyed by id.
@model
final class ModelsDevDocument {
  const ModelsDevDocument._(this._providers);

  /// Null when [text] is not a JSON object.
  static ModelsDevDocument? parse(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, Object?>
          ? ModelsDevDocument._(decoded)
          : null;
    } on FormatException {
      return null;
    }
  }

  static const _tokensPerPriceUnit = 1000000;

  final Map<String, Object?> _providers;

  /// Every model the catalog lists under [catalogId]; empty when unknown.
  List<ProviderModel> modelsFor(String catalogId) {
    final provider = _providers[catalogId];
    final models = provider is Map<String, Object?> ? provider['models'] : null;
    if (models is! Map<String, Object?>) return const [];
    return [
      for (final entry in models.entries)
        if (entry.value case final Map<String, Object?> model)
          _toModel(entry.key, model),
    ];
  }

  static ProviderModel _toModel(String id, Map<String, Object?> model) {
    final limit = model['limit'];
    final cost = model['cost'];
    return ProviderModel(
      id: id,
      name: switch (model['name']) {
        final String name when name.isNotEmpty => name,
        _ => id,
      },
      contextLength: switch (limit) {
        {'context': final num context} => context.toInt(),
        _ => null,
      },
      supportsTools: model['tool_call'] == true,
      reasoning: model['reasoning'] == true
          ? _toReasoning(model['reasoning_options'])
          : null,
      promptPricePerToken: switch (cost) {
        {'input': final num input} => input / _tokensPerPriceUnit,
        _ => null,
      },
      completionPricePerToken: switch (cost) {
        {'output': final num output} => output / _tokensPerPriceUnit,
        _ => null,
      },
    );
  }

  /// models.dev lists the controls a thinking model accepts: an on/off
  /// `toggle`, named `effort` values, or a `budget_tokens` range. Named
  /// efforts win; a toggle alone is a toggle; anything else means the
  /// model thinks on its own terms.
  static ProviderReasoning _toReasoning(Object? options) {
    if (options is! List<Object?>) return const ProviderReasoningFixed();
    var hasToggle = false;
    var hadNone = false;
    final efforts = <String>[];
    for (final option in options.whereType<Map<String, Object?>>()) {
      switch (option) {
        case {'type': 'toggle'}:
          hasToggle = true;
        case {'type': 'effort', 'values': final List<Object?> values}:
          for (final value in values.whereType<String>()) {
            if (value == 'none') {
              hadNone = true;
            } else {
              efforts.add(value);
            }
          }
      }
    }
    if (efforts.isNotEmpty) {
      return ProviderReasoningEfforts(
        efforts: efforts,
        canDisable: hasToggle || hadNone,
      );
    }
    return hasToggle
        ? const ProviderReasoningToggle()
        : const ProviderReasoningFixed();
  }
}
