import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A request's connection taken over from the HTTP server. Replies are
/// written straight to the socket, so the server learns the moment the
/// client hangs up and can still choose a status after work has begun.
final class ClientConnection {
  ClientConnection._(this._socket) {
    Future.any([
      _socket.drain<void>(),
      _socket.done,
    ]).whenComplete(_hangUp).ignore();
  }

  /// Takes [request]'s connection. Its body must already have been read.
  static Future<ClientConnection> take(HttpRequest request) async =>
      ClientConnection._(
        await request.response.detachSocket(writeHeaders: false),
      );

  final Socket _socket;
  final _closed = Completer<void>();
  var _writable = true;

  /// Completes when the client hangs up or the connection is ended.
  Future<void> get closed => _closed.future;

  /// Sends [json], already encoded, as the whole response and ends the
  /// connection.
  Future<void> reply(String json, {int status = HttpStatus.ok}) {
    final body = utf8.encode(json);
    _write(
      _head(status, {
        HttpHeaders.contentTypeHeader: '${ContentType.json}',
        HttpHeaders.contentLengthHeader: '${body.length}',
      }),
    );
    if (_writable) _socket.add(body);
    return end();
  }

  /// Begins a server-sent event stream.
  void startEvents() => _write(
    _head(HttpStatus.ok, {
      HttpHeaders.contentTypeHeader: 'text/event-stream; charset=utf-8',
      HttpHeaders.cacheControlHeader: 'no-cache',
    }),
  );

  void send(Object? json) => _write('data: ${jsonEncode(json)}\n\n');

  /// Sends the `[DONE]` marker and ends the stream.
  Future<void> finish() {
    _write('data: [DONE]\n\n');
    return end();
  }

  /// Flushes what was sent and closes the connection. Nothing more is sent
  /// once it begins.
  Future<void> end() async {
    if (!_writable) return;
    _writable = false;
    await _socket.flush().then((_) {}, onError: (Object _) {});
    _hangUp();
  }

  static String _head(int status, Map<String, String> headers) => [
    'HTTP/1.1 $status ${_reasons[status] ?? 'Status'}',
    for (final MapEntry(:key, :value) in headers.entries) '$key: $value',
    '${HttpHeaders.connectionHeader}: close',
    '',
    '',
  ].join('\r\n');

  static const Map<int, String> _reasons = {
    HttpStatus.ok: 'OK',
    HttpStatus.badRequest: 'Bad Request',
    HttpStatus.forbidden: 'Forbidden',
    HttpStatus.notFound: 'Not Found',
    HttpStatus.conflict: 'Conflict',
    HttpStatus.internalServerError: 'Internal Server Error',
    HttpStatus.serviceUnavailable: 'Service Unavailable',
  };

  void _write(String text) {
    if (_writable) _socket.write(text);
  }

  void _hangUp() {
    _writable = false;
    if (_closed.isCompleted) return;
    _closed.complete();
    _socket.destroy();
  }
}
