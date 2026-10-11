import 'dart:async';

import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/connection/server_connection_data.dart';
import 'package:provider_local/src/connection/server_connection_input.dart';
import 'package:provider_local/src/connection/server_connection_logic.dart';
import 'package:provider_local/src/models/server_results.dart';
import 'package:test/test.dart';

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
