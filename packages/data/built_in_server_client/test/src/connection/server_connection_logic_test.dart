import 'dart:async';
import 'dart:convert';

import 'package:built_in_server_client/src/connection/server_connection_data.dart';
import 'package:built_in_server_client/src/connection/server_connection_input.dart';
import 'package:built_in_server_client/src/connection/server_connection_logic.dart';
import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:built_in_server_client/src/owner_session.dart';
import 'package:built_in_server_client/src/server_attacher.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

/// An owner session opened over a stream that stays open.
Future<OwnerSession> openSession() async {
  final opening = await OwnerSession.open(
    client: MockClient.streaming((request, _) async {
      final body = StreamController<List<int>>();
      const opened = SessionOpened(ownerToken: 'token');
      body.add(utf8.encode('data: ${opened.toJson()}\n\n'));
      return http.StreamedResponse(body.stream, 200);
    }),
    port: 4100,
    pid: 77,
  );
  return (opening as OwnerSessionOpened).session;
}

void main() {
  group('disconnected', () {
    test('refuses a load, since it holds no session', () async {
      final state = DisconnectedState();
      state.createFakeContext().set(ServerConnectionData());
      final reply = Completer<ModelLoadResult>();

      final transition = state.handleInput(
        LoadRequested(
          request: const ModelLoadRequest(localId: 'qwen', maxAgents: 1),
          reply: reply,
        ),
      );

      expect(transition.stateType, DisconnectedState);
      expect(
        (await reply.future as ModelLoadFailed).reason,
        ServerConnectionState.notAttached,
      );
    });
  });

  group('losing', () {
    late ServerConnectionData data;
    late LosingState state;

    setUp(() async {
      data = ServerConnectionData()
        ..attempt = 2
        ..holding = AttachHeld(
          session: await openSession(),
          attached: const BuiltInServerAttached(
            ownerToken: 'token',
            port: 4100,
            pid: 42,
          ),
          exit: Completer<ProcessExit>().future,
        );
      state = LosingState(grace: const Duration(seconds: 1));
      state.createFakeContext().set(data);
    });

    test('ignores the exit of a process that served another session', () async {
      final transition = state.handleInput(
        ProcessExitReported(
          session: await openSession(),
          exit: const ProcessSignaled(11),
        ),
      );

      expect(transition.stateType, LosingState);
    });

    test('ignores the grace of an earlier attempt running out', () {
      final transition = state.handleInput(
        const LossGraceExpired(attempt: 1),
      );

      expect(transition.stateType, LosingState);
    });
  });

  group('closed', () {
    test('answers a repeated close once it has hung up', () async {
      final hungUp = Completer<void>();
      final state = ClosedState();
      state.createFakeContext().set(
        ServerConnectionData()..hungUp = hungUp.future,
      );
      final reply = Completer<void>();
      var answered = false;
      unawaited(reply.future.then((_) => answered = true));

      final transition = state.handleInput(CloseRequested(reply));
      await pumpEventQueue();

      expect(transition.stateType, ClosedState);
      expect(answered, isFalse);
      hungUp.complete();
      await pumpEventQueue();
      expect(answered, isTrue);
    });
  });
}
