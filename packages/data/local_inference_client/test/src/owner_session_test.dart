import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_inference_client/src/owner_session.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:test/test.dart';

void main() {
  late StreamController<List<int>> body;
  late List<http.BaseRequest> requests;
  late int status;

  String frame(SessionEvent event) => 'data: ${event.toJson()}\n\n';

  void send(String text) => body.add(utf8.encode(text));

  Future<OwnerSessionOpening> open() => OwnerSession.open(
    client: MockClient.streaming((request, _) async {
      requests.add(request);
      return http.StreamedResponse(body.stream, status);
    }),
    port: 4100,
    pid: 77,
  );

  setUp(() {
    body = StreamController<List<int>>();
    requests = [];
    status = 200;
  });

  test('opens with the token of the first event', () async {
    send(frame(const SessionOpened(ownerToken: 'token')));

    final opening = await open();

    expect((opening as OwnerSessionOpened).session.ownerToken, 'token');
    final request = requests.single;
    expect(request.url.toString(), 'http://127.0.0.1:4100$bestieSessionPath');
    expect(request.headers[bestieOwnerPidHeader], '77');
  });

  test('streams the events after the opening one', () async {
    send(frame(const SessionOpened(ownerToken: 'token')));
    final session = (await open() as OwnerSessionOpened).session;
    final events = <SessionEvent>[];
    final done = session.events.forEach(events.add);

    send(': keep-alive\n\n');
    send('event: unknown\ndata: {"type":"from_the_future"}\n\n');
    send(frame(const ModelStatusEvent(status: ModelUnloaded())));
    send(
      frame(
        const PoolSnapshotEvent(contextSize: 8192, maxAgents: 3, agents: []),
      ),
    );
    await body.close();
    await done;

    expect(events, [
      const ModelStatusEvent(status: ModelUnloaded()),
      const PoolSnapshotEvent(contextSize: 8192, maxAgents: 3, agents: []),
    ]);
  });

  test('ends the events quietly when the stream breaks', () async {
    send(frame(const SessionOpened(ownerToken: 'token')));
    final session = (await open() as OwnerSessionOpened).session;
    final done = session.events.toList();

    body.addError(http.ClientException('reset'));

    expect(await done, isEmpty);
  });

  test('ends the events when closed', () async {
    send(frame(const SessionOpened(ownerToken: 'token')));
    final session = (await open() as OwnerSessionOpened).session;

    await session.close();

    expect(await session.events.toList(), isEmpty);
  });

  test('is refused while another bestie owns the server', () async {
    status = ServerBusy.statusCode;
    send(const ServerBusy(ownerPid: 12).toJson());
    unawaited(body.close());

    final opening = await open();

    expect((opening as OwnerSessionRefused).ownerPid, 12);
  });

  test('fails on any other status', () async {
    status = 500;
    unawaited(body.close());

    final opening = await open();

    expect(
      (opening as OwnerSessionFailed).reason,
      'The local model server answered the session with HTTP 500.',
    );
  });

  test('fails when the stream does not open with the token', () async {
    send(frame(const ModelStatusEvent(status: ModelUnloaded())));

    final opening = await open();

    expect(
      (opening as OwnerSessionFailed).reason,
      'The local model server did not open the session.',
    );
  });

  test('fails when the stream ends before the token', () async {
    unawaited(body.close());

    final opening = await open();

    expect(opening, isA<OwnerSessionFailed>());
  });

  test('fails when the stream breaks before the token', () async {
    body.addError(http.ClientException('reset'));

    final opening = await open();

    expect((opening as OwnerSessionFailed).reason, contains('reset'));
  });

  test('finds the server gone when it is unreachable', () async {
    final opening = await OwnerSession.open(
      client: MockClient((_) => throw http.ClientException('refused')),
      port: 4100,
      pid: 77,
    );

    expect((opening as OwnerSessionServerGone).reason, contains('refused'));
  });

  test('finds the server gone when it is shutting down', () async {
    status = 503;
    send(
      jsonEncode({
        'error': {
          'message': 'The server is shutting down.',
          'type': 'server_error',
          'code': 'shutting_down',
        },
      }),
    );
    unawaited(body.close());

    final opening = await open();

    expect(
      (opening as OwnerSessionServerGone).reason,
      'The server is shutting down.',
    );
  });

  test('finds the server gone on an unreadable 503', () async {
    status = 503;
    send('busy');
    unawaited(body.close());

    final opening = await open();

    expect(
      (opening as OwnerSessionServerGone).reason,
      'The local model server answered the session with HTTP 503.',
    );
  });
}
