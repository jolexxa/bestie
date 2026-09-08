import 'package:dart_mappable/dart_mappable.dart';
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceDialect;

part 'provider_descriptor.mapper.dart';

/// What we know about a provider before talking to it.
@MappableClass()
final class ProviderDescriptor with ProviderDescriptorMappable {
  const ProviderDescriptor({
    required this.id,
    required this.displayName,
    required this.requiresApiKey,
    required this.dialect,
    this.requiresBaseUrl = false,
    this.baseUrl,
    this.catalogId,
  });

  /// Stable identifier, e.g. `openrouter`.
  final String id;

  final String displayName;

  final bool requiresApiKey;

  /// Vendor extensions the provider's OpenAI-compatible endpoint speaks.
  final InferenceDialect dialect;

  /// Whether the user must supply the endpoint address.
  final bool requiresBaseUrl;

  /// Where the OpenAI-compatible endpoint lives; null when the provider
  /// knows its own address or the user supplies one.
  final Uri? baseUrl;

  /// The provider's id in the external model catalog, when listed there.
  final String? catalogId;
}
