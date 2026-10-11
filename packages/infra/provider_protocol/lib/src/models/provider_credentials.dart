import 'package:meta/meta.dart';

/// What the user gave us to reach one provider.
@immutable
sealed class ProviderCredentials {
  const ProviderCredentials();
}

/// A provider that needs nothing from the user.
final class NoCredentials extends ProviderCredentials {
  const NoCredentials();

  @override
  bool operator ==(Object other) => other is NoCredentials;

  @override
  int get hashCode => (NoCredentials).hashCode;

  @override
  String toString() => 'NoCredentials()';
}

/// A provider that knows its own address and wants a key.
final class ApiKeyCredentials extends ProviderCredentials {
  const ApiKeyCredentials(this.apiKey);

  final String apiKey;

  @override
  bool operator ==(Object other) =>
      other is ApiKeyCredentials && other.apiKey == apiKey;

  @override
  int get hashCode => apiKey.hashCode;

  /// Never prints the key.
  @override
  String toString() => 'ApiKeyCredentials(set)';
}

/// A provider the user points at an address of their own.
final class EndpointCredentials extends ProviderCredentials {
  const EndpointCredentials({
    required this.baseUrl,
    required this.fallbackContextWindow,
    this.apiKey,
  });

  final Uri baseUrl;

  /// The bearer token, when the endpoint wants one.
  final String? apiKey;

  /// Context window to assume when the endpoint does not report one.
  final int fallbackContextWindow;

  @override
  bool operator ==(Object other) =>
      other is EndpointCredentials &&
      other.baseUrl == baseUrl &&
      other.apiKey == apiKey &&
      other.fallbackContextWindow == fallbackContextWindow;

  @override
  int get hashCode => Object.hash(baseUrl, apiKey, fallbackContextWindow);

  /// Never prints the key.
  @override
  String toString() =>
      'EndpointCredentials($baseUrl, '
      'apiKey: ${apiKey == null ? 'unset' : 'set'}, '
      'fallbackContextWindow: $fallbackContextWindow)';
}
