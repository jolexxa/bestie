import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderDescriptor;
import 'package:provider_protocol/provider_protocol_mappers.dart';

part 'provider_account.mapper.dart';

/// What the user gave us for one provider.
@model
@MappableClass(generateMethods: GenerateMethods.equals | GenerateMethods.copy)
final class ProviderAccount with ProviderAccountMappable {
  const ProviderAccount({
    required this.descriptor,
    required this.apiKey,
    this.baseUrl,
    this.fallbackContextWindow,
  });

  final ProviderDescriptor descriptor;

  final String apiKey;

  /// The endpoint address, for providers that leave it to the user.
  final Uri? baseUrl;

  /// Context window to assume when the endpoint does not report one.
  final int? fallbackContextWindow;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// The address to talk to: the provider's own, else the user's.
  Uri? get resolvedBaseUrl => descriptor.baseUrl ?? baseUrl;

  /// Whether a provider can be built from what the user gave.
  bool get isUsable =>
      (!descriptor.requiresApiKey || hasApiKey) &&
      (!descriptor.requiresBaseUrl || baseUrl != null);

  /// Never prints the key.
  @override
  String toString() =>
      'ProviderAccount(${descriptor.id}, '
      'apiKey: ${hasApiKey ? 'set' : 'unset'}, baseUrl: $baseUrl)';
}
