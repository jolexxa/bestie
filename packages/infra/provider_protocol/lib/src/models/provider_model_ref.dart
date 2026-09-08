import 'package:dart_mappable/dart_mappable.dart';

part 'provider_model_ref.mapper.dart';

/// A model named together with the provider that serves it.
@MappableClass()
final class ProviderModelRef with ProviderModelRefMappable {
  const ProviderModelRef({required this.providerId, required this.modelId});

  /// Reads the `provider:model` form written by [qualified]; null when
  /// [text] names no provider or no model.
  static ProviderModelRef? parse(String text) {
    final separator = text.indexOf(':');
    if (separator <= 0 || separator == text.length - 1) return null;
    return ProviderModelRef(
      providerId: text.substring(0, separator),
      modelId: text.substring(separator + 1),
    );
  }

  final String providerId;

  final String modelId;

  /// The `provider:model` form, e.g. `openrouter:openai/gpt-4o-mini`.
  String get qualified => '$providerId:$modelId';
}
