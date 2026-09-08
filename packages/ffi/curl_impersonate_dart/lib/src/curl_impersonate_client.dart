import 'dart:convert';

import 'package:curl_impersonate_dart/src/curl_impersonate.dart';
import 'package:http/http.dart' as http;

/// Performs a curl-impersonate request.
typedef CurlFetch =
    Future<CurlResponse> Function(String libraryPath, CurlRequest request);

/// Request headers that the impersonation target owns to keep its browser
/// fingerprint coherent.
const _fingerprintHeaders = {
  'user-agent',
  'accept',
  'accept-encoding',
  'accept-language',
};

/// An [http.Client] backed by curl-impersonate.
class CurlImpersonateClient extends http.BaseClient {
  /// Creates a client that routes requests through curl-impersonate loaded from
  /// [libraryPath].
  CurlImpersonateClient({
    required this.libraryPath,
    this.caCertPath,
    this.impersonate = 'chrome146',
    CurlFetch? fetch,
  }) : _fetch = fetch ?? CurlImpersonate.fetch;

  /// Path to the curl-impersonate dynamic library.
  final String libraryPath;

  /// Absolute path to a PEM CA bundle for TLS verification.
  final String? caCertPath;

  /// The browser fingerprint to impersonate.
  final String impersonate;

  final CurlFetch _fetch;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();

    final headers = <String, String>{};
    request.headers.forEach((key, value) {
      final lower = key.toLowerCase();
      if (_fingerprintHeaders.contains(lower) || lower.startsWith('sec-')) {
        return;
      }
      headers[key] = value;
    });

    final body = bodyBytes.isNotEmpty
        ? utf8.decode(bodyBytes)
        : (request.method == 'POST' ? '' : null);

    final response = await _fetch(
      libraryPath,
      CurlRequest(
        url: request.url.toString(),
        headers: headers.isEmpty ? null : headers,
        body: body,
        impersonate: impersonate,
        caCertPath: caCertPath,
      ),
    );

    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      contentLength: response.bodyBytes.length,
    );
  }
}
