import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// Where the user pointed bestie, and what to assume about the server there.
@model
@immutable
final class OpenAiEndpointSettings {
  const OpenAiEndpointSettings({
    this.baseUrl,
    this.apiKey,
    this.contextWindow = defaultContextWindow,
  });

  /// What to assume for a server that does not report its context.
  static const int defaultContextWindow = 32768;

  /// Nothing has been given yet.
  static const unset = OpenAiEndpointSettings();

  /// The OpenAI-compatible base URL, including the version segment.
  final Uri? baseUrl;

  /// The bearer token, when the endpoint wants one.
  final String? apiKey;

  /// Context window to assume when the endpoint does not report one.
  final int contextWindow;

  bool get isSet => baseUrl != null;

  @override
  bool operator ==(Object other) =>
      other is OpenAiEndpointSettings &&
      other.baseUrl == baseUrl &&
      other.apiKey == apiKey &&
      other.contextWindow == contextWindow;

  @override
  int get hashCode => Object.hash(baseUrl, apiKey, contextWindow);

  /// Never prints the key.
  @override
  String toString() =>
      'OpenAiEndpointSettings(${baseUrl ?? 'unset'}, '
      'apiKey: ${apiKey == null ? 'unset' : 'set'}, '
      'contextWindow: $contextWindow)';
}
