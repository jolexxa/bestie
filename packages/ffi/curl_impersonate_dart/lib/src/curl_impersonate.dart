import 'dart:convert';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:curl_impersonate_dart/src/bindings/curl_impersonate_bindings.dart';
import 'package:ffi/ffi.dart';

// Data classes — public fields are self-documenting. Sequential setopt calls
// on _bindings are intentionally not cascaded (they return CURLcode).
// ignore_for_file: public_member_api_docs, cascade_invocations

/// A request to be performed by curl-impersonate.
class CurlRequest {
  const CurlRequest({
    required this.url,
    this.headers,
    this.body,
    // Latest target from impersonations[] in lib/impersonate.c — update
    // when bumping the curl-impersonate submodule.
    this.impersonate = 'chrome146',
    this.timeoutSeconds = 30,
    this.connectTimeoutSeconds = 15,
    this.caCertPath,
  });

  final String url;
  final Map<String, String>? headers;
  final String? body;
  final String impersonate;
  final int timeoutSeconds;
  final int connectTimeoutSeconds;

  /// Absolute path to a PEM CA bundle for TLS verification.
  ///
  /// The prebuilt curl-impersonate libraries bake in CA paths that only
  /// exist on the distro they were built on, so hosts without those paths
  /// fail every HTTPS request with a bad-CA error. Supplying this points
  /// `CURLOPT_CAINFO` at a bundle that is known to exist. When null, curl's
  /// compiled-in default is used.
  final String? caCertPath;
}

/// Response received from a curl-impersonate fetch.
class CurlResponse {
  const CurlResponse({
    required this.statusCode,
    required this.bodyBytes,
    this.headers = const {},
  });

  final int statusCode;
  final Uint8List bodyBytes;

  /// Response headers, keyed by lowercased name.
  final Map<String, String> headers;

  /// Decodes the body as UTF-8 (lossy).
  String get body => utf8.decode(bodyBytes, allowMalformed: true);
}

/// Parses raw curl header lines into a map keyed by lowercased name.
Map<String, String> parseCurlHeaders(List<String> lines) {
  final headers = <String, String>{};
  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (line.startsWith('HTTP/')) {
      headers.clear();
      continue;
    }
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final name = line.substring(0, colon).trim().toLowerCase();
    final value = line.substring(colon + 1).trim();
    headers[name] = headers.containsKey(name)
        ? '${headers[name]}, $value'
        : value;
  }
  return headers;
}

/// Exception thrown when a curl operation fails.
class CurlException implements Exception {
  const CurlException(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => 'CurlException($code): $message';
}

/// High-level wrapper around libcurl-impersonate.
class CurlImpersonate {
  /// Open the dynamic library from [libraryPath].
  factory CurlImpersonate.open({required String libraryPath}) {
    final lib = DynamicLibrary.open(libraryPath);
    return CurlImpersonate._(CurlImpersonateBindings(lib));
  }

  CurlImpersonate._(this._bindings);

  final CurlImpersonateBindings _bindings;

  /// Default library file name for the current platform.
  static String defaultLibraryFileName() {
    if (Platform.isMacOS) return 'libcurl-impersonate.dylib';
    if (Platform.isLinux) return 'libcurl-impersonate.so';
    if (Platform.isWindows) return 'libcurl-impersonate.dll';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Initialize curl globally. Call once from the main isolate.
  static void globalInit(String libraryPath) {
    final lib = DynamicLibrary.open(libraryPath);
    final bindings = CurlImpersonateBindings(lib);
    final code = bindings.curl_global_init(CURL_GLOBAL_DEFAULT);
    if (code != CURLcode.CURLE_OK) {
      throw CurlException(code.value, 'curl_global_init failed');
    }
  }

  /// Clean up global curl state.
  static void globalCleanup(String libraryPath) {
    final lib = DynamicLibrary.open(libraryPath);
    final bindings = CurlImpersonateBindings(lib);
    bindings.curl_global_cleanup();
  }

  /// Fetch a URL synchronously. **Must be called from an isolate** — this
  /// blocks the calling thread until the request completes.
  CurlResponse fetchSync(CurlRequest request) {
    final handle = _bindings.curl_easy_init();
    if (handle == nullptr) {
      throw const CurlException(-1, 'curl_easy_init returned null');
    }

    // Native string pointers must outlive curl_easy_perform — curl stores
    // the pointer without copying. Free them in the finally block.
    final nativePtrs = <Pointer<Utf8>>[];
    Pointer<Char> nativeStr(String s) {
      final ptr = s.toNativeUtf8();
      nativePtrs.add(ptr);
      return ptr.cast<Char>();
    }

    // Accumulate response bytes via write callback.
    final chunks = <Uint8List>[];
    final writeCallback =
        NativeCallable<
          Size Function(Pointer<Uint8>, Size, Size, Pointer<Void>)
        >.isolateLocal(
          (Pointer<Uint8> ptr, int size, int nmemb, Pointer<Void> _) {
            final totalSize = size * nmemb;
            chunks.add(Uint8List.fromList(ptr.asTypedList(totalSize)));
            return totalSize;
          },
          exceptionalReturn: 0,
        );

    // Accumulate response header lines.
    final headerLines = <String>[];
    final headerCallback =
        NativeCallable<
          Size Function(Pointer<Uint8>, Size, Size, Pointer<Void>)
        >.isolateLocal(
          (Pointer<Uint8> ptr, int size, int nmemb, Pointer<Void> _) {
            final totalSize = size * nmemb;
            headerLines.add(latin1.decode(ptr.asTypedList(totalSize)));
            return totalSize;
          },
          exceptionalReturn: 0,
        );

    var slist = Pointer<curl_slist>.fromAddress(0);

    try {
      // URL
      _bindings.curl_easy_setoptString(
        handle,
        CURLoption.CURLOPT_URL,
        nativeStr(request.url),
      );

      // Write callback
      _bindings.curl_easy_setoptPtr(
        handle,
        CURLoption.CURLOPT_WRITEFUNCTION,
        writeCallback.nativeFunction.cast(),
      );

      // Header callback
      _bindings.curl_easy_setoptPtr(
        handle,
        CURLoption.CURLOPT_HEADERFUNCTION,
        headerCallback.nativeFunction.cast(),
      );

      // Timeouts
      _bindings.curl_easy_setoptLong(
        handle,
        CURLoption.CURLOPT_TIMEOUT,
        request.timeoutSeconds,
      );
      _bindings.curl_easy_setoptLong(
        handle,
        CURLoption.CURLOPT_CONNECTTIMEOUT,
        request.connectTimeoutSeconds,
      );

      // Follow redirects
      _bindings.curl_easy_setoptLong(
        handle,
        CURLoption.CURLOPT_FOLLOWLOCATION,
        1,
      );

      // Accept compressed responses
      _bindings.curl_easy_setoptString(
        handle,
        CURLoption.CURLOPT_ACCEPT_ENCODING,
        nativeStr(''),
      );

      // CA bundle for TLS verification. Overrides the library's compiled-in
      // default, which may point at a path that does not exist on this host.
      final caCertPath = request.caCertPath;
      if (caCertPath != null) {
        _bindings.curl_easy_setoptString(
          handle,
          CURLoption.CURLOPT_CAINFO,
          nativeStr(caCertPath),
        );
      }

      // Impersonate a browser
      _bindings.curl_easy_impersonate(
        handle,
        nativeStr(request.impersonate),
        1,
      );

      // Custom headers
      final headers = request.headers;
      if (headers != null && headers.isNotEmpty) {
        for (final entry in headers.entries) {
          slist = _bindings.curl_slist_append(
            slist,
            nativeStr('${entry.key}: ${entry.value}'),
          );
        }
        _bindings.curl_easy_setoptPtr(
          handle,
          CURLoption.CURLOPT_HTTPHEADER,
          slist.cast(),
        );
      }

      // POST body
      final body = request.body;
      if (body != null) {
        _bindings.curl_easy_setoptLong(handle, CURLoption.CURLOPT_POST, 1);
        _bindings.curl_easy_setoptString(
          handle,
          CURLoption.CURLOPT_POSTFIELDS,
          nativeStr(body),
        );
      }

      // Perform the request (blocks)
      final result = _bindings.curl_easy_perform(handle);
      if (result != CURLcode.CURLE_OK) {
        final msg = _bindings
            .curl_easy_strerror(result)
            .cast<Utf8>()
            .toDartString();
        throw CurlException(result.value, msg);
      }

      final statusCodePtr = malloc<Long>();
      final int statusCode;
      try {
        _bindings.curl_easy_getinfoLong(
          handle,
          CURLINFO.CURLINFO_RESPONSE_CODE,
          statusCodePtr,
        );
        statusCode = statusCodePtr.value;
      } finally {
        malloc.free(statusCodePtr);
      }

      // Merge chunks into a single Uint8List.
      final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
      final merged = Uint8List(totalLength);
      var offset = 0;
      for (final chunk in chunks) {
        merged.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      return CurlResponse(
        statusCode: statusCode,
        bodyBytes: merged,
        headers: parseCurlHeaders(headerLines),
      );
    } finally {
      writeCallback.close();
      headerCallback.close();
      if (slist.address != 0) _bindings.curl_slist_free_all(slist);
      _bindings.curl_easy_cleanup(handle);
      nativePtrs.forEach(malloc.free);
    }
  }

  /// Fetch a URL asynchronously using [Isolate.run].
  static Future<CurlResponse> fetch(
    String libraryPath,
    CurlRequest request,
  ) {
    return Isolate.run(() {
      final curl = CurlImpersonate.open(libraryPath: libraryPath);
      return curl.fetchSync(request);
    });
  }
}
