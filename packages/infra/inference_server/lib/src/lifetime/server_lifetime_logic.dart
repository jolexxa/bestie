import 'dart:async';

import 'package:inference_server/src/lifetime/server_lifetime_data.dart';
import 'package:inference_server/src/lifetime/server_lifetime_input.dart';
import 'package:inference_server/src/lifetime/server_lifetime_output.dart';
import 'package:inference_server/src/lifetime/server_stop_reason.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// Keeps the server up exactly as long as it has a connection. A fresh
/// server waits [startupGrace] for its first one; after that, the last one
/// closing stops it at once.
final class ServerLifetimeLogic extends LogicBlock<ServerLifetimeState> {
  ServerLifetimeLogic({required this.startupGrace}) {
    set(ServerLifetimeData());
    set(AwaitingFirstState());
    set(ServingState());
    set(DrainingState());
  }

  final Duration startupGrace;

  ServerLifetimeData get _data => get<ServerLifetimeData>();

  @override
  Transition getInitialState() => to<AwaitingFirstState>();

  @override
  void onStart() {
    _data.grace = Timer(startupGrace, () => input(const GraceExpired()));
  }

  @override
  void onStop() {
    _data.grace?.cancel();
  }
}

sealed class ServerLifetimeState extends StateLogic<ServerLifetimeState> {
  ServerLifetimeData get data => get<ServerLifetimeData>();

  /// Whether a new connection is still taken on.
  bool get admits => true;

  Transition drain(ServerStopReason reason) {
    output(ShutdownCommitted(reason));
    return to<DrainingState>();
  }

  Transition onShutdownRequested(ShutdownRequested _) =>
      drain(ServerStopReason.requested);
}

/// Freshly started: nothing has connected yet, and the grace is running.
final class AwaitingFirstState extends ServerLifetimeState {
  AwaitingFirstState() {
    onExit(() => data.grace?.cancel());
    on<ConnectionOpened>((_) {
      data.connections = 1;
      return to<ServingState>();
    });
    on<GraceExpired>((_) => drain(ServerStopReason.unclaimed));
    on<ShutdownRequested>(onShutdownRequested);
  }
}

/// At least one connection is open.
final class ServingState extends ServerLifetimeState {
  ServingState() {
    on<ConnectionOpened>((_) {
      data.connections++;
      return toSelf();
    });
    on<ConnectionClosed>((_) {
      data.connections--;
      return data.connections == 0 ? drain(ServerStopReason.drained) : toSelf();
    });
    on<ShutdownRequested>(onShutdownRequested);
  }
}

/// Shutdown is committed; connections still closing change nothing.
final class DrainingState extends ServerLifetimeState {
  @override
  bool get admits => false;
}
