import 'package:inference_protocol/src/models/inference_dialect.dart';
import 'package:meta/meta.dart';

/// Where an OpenAI-compatible server lives and how to authenticate with it.
@immutable
final class InferenceEndpoint {
  const InferenceEndpoint({
    required this.baseUrl,
    this.apiKey,
    this.headers = const {},
    this.dialect = InferenceDialect.openAi,
  });

  /// Base URL up to and including the API version segment, e.g.
  /// `https://openrouter.ai/api/v1`.
  final Uri baseUrl;

  /// Bearer token sent with every request, when the server wants one.
  final String? apiKey;

  /// Extra headers sent with every request.
  final Map<String, String> headers;

  /// Vendor extensions the server understands.
  final InferenceDialect dialect;

  @override
  bool operator ==(Object other) =>
      other is InferenceEndpoint &&
      other.baseUrl == baseUrl &&
      other.apiKey == apiKey &&
      other.dialect == dialect &&
      _headersEqual(other.headers);

  bool _headersEqual(Map<String, String> other) {
    if (other.length != headers.length) {
      return false;
    }
    for (final entry in headers.entries) {
      if (other[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(baseUrl, apiKey, dialect, headers.length);

  @override
  String toString() => 'InferenceEndpoint($baseUrl)';
}
