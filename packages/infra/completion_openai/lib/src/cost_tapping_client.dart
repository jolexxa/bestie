import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Carries a streaming request unchanged while reading the charge a provider
/// stamps on the `usage` of its final `data:` line.
final class CostTappingClient extends http.BaseClient {
  CostTappingClient(this._inner, {required this.onCost});

  final http.Client _inner;
  var _closed = false;

  /// Called with each charge read off the stream; the last one is the bill.
  final void Function(double cost) onCost;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    return http.StreamedResponse(
      response.stream.transform(_tap()),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  /// Closes the wire once, however many hands let go of it.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _inner.close();
  }

  /// Passes every chunk through untouched while reassembling `data:` lines
  /// across chunk boundaries on the side.
  StreamTransformer<List<int>, List<int>> _tap() {
    final lines = utf8.decoder.startChunkedConversion(
      const LineSplitter().startChunkedConversion(_LineSink(_readLine)),
    );
    return StreamTransformer.fromHandlers(
      handleData: (chunk, sink) {
        sink.add(chunk);
        lines.add(chunk);
      },
      handleDone: (sink) {
        lines.close();
        sink.close();
      },
    );
  }

  void _readLine(String line) {
    if (!line.startsWith(_dataPrefix) || !line.contains('"cost"')) return;
    final payload = line.substring(_dataPrefix.length).trim();
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return;
    }
    if (decoded case {'usage': {'cost': final num cost}}) {
      onCost(cost.toDouble());
    }
  }

  static const _dataPrefix = 'data:';
}

final class _LineSink implements Sink<String> {
  const _LineSink(this._onLine);

  final void Function(String line) _onLine;

  @override
  void add(String data) => _onLine(data);

  @override
  void close() {}
}
