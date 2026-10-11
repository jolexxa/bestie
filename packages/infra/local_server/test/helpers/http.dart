import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A finished response from the server under test.
final class Reply {
  const Reply({required this.status, required this.body});

  final int status;
  final String body;

  Object? get json => jsonDecode(body);

  Map<String, Object?> get object => json! as Map<String, Object?>;

  /// The OpenAI error code, for error replies.
  Object? get errorCode => (object['error']! as Map)['code'];
}

/// Talks to a server on the loopback interface.
final class TestClient {
  TestClient(this.port);

  final int port;
  final _client = HttpClient();

  Future<HttpClientResponse> open(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final request = await _client.open(method, '127.0.0.1', port, path);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.write(body is String ? body : jsonEncode(body));
    }
    return request.close();
  }

  Future<Reply> send(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final response = await open(method, path, headers: headers, body: body);
    return Reply(
      status: response.statusCode,
      body: await utf8.decoder.bind(response).join(),
    );
  }

  /// Opens a server-sent event stream and reads its events as they come.
  Future<EventReader> events(
    String path, {
    String method = 'GET',
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final response = await open(method, path, headers: headers, body: body);
    return EventReader(response);
  }

  /// Sends a request over a bare socket, so the test can hang up before any
  /// response arrives.
  Future<Socket> raw(String method, String path, {Object? body}) async {
    final encoded = utf8.encode(body == null ? '' : jsonEncode(body));
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    socket
      ..write(
        '$method $path HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${encoded.length}\r\n\r\n',
      )
      ..add(encoded);
    await socket.flush();
    return socket;
  }

  void close() => _client.close(force: true);
}

/// Reads `data:` lines from an event stream.
final class EventReader {
  EventReader(this.response) {
    _subscription = utf8.decoder
        .bind(response)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data: '))
        .map((line) => line.substring('data: '.length))
        .listen(_arrived.add, onDone: _arrived.close);
  }

  final HttpClientResponse response;
  final _arrived = StreamController<String>();
  late final StreamSubscription<String> _subscription;
  late final StreamIterator<String> _queue = StreamIterator(_arrived.stream);

  /// The next event's data, or null once the stream has ended.
  Future<String?> next() async =>
      await _queue.moveNext() ? _queue.current : null;

  Future<Map<String, Object?>> nextJson() async =>
      jsonDecode((await next())!) as Map<String, Object?>;

  /// Every remaining event's data, until the server ends the stream.
  Future<List<String>> rest() async => [
    for (var data = await next(); data != null; data = await next()) data,
  ];

  /// Hangs up on the server.
  Future<void> hangUp() async {
    await _subscription.cancel();
    final socket = await response.detachSocket();
    socket.destroy();
  }
}
