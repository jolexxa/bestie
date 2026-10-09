import 'dart:async';

import 'package:local_inference_client/src/connection/server_connection_data.dart';
import 'package:local_inference_client/src/connection/server_connection_input.dart';
import 'package:local_inference_client/src/connection/server_connection_logic.dart';
import 'package:test/test.dart';

void main() {
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
