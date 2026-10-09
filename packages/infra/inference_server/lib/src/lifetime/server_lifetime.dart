import 'dart:async';

import 'package:inference_server/src/lifetime/server_lifetime_input.dart';
import 'package:inference_server/src/lifetime/server_lifetime_logic.dart';
import 'package:inference_server/src/lifetime/server_lifetime_output.dart';
import 'package:inference_server/src/lifetime/server_stop_reason.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// Decides when the server stops: once its last connection closes, or when
/// nothing connects within [startupGrace] of starting.
///
/// Opening and closing a connection are both handled synchronously, so the
/// last close and a new request can never interleave: shutdown is committed
/// only while no connection is open, and from then on [shuttingDown] turns
/// every newcomer away.
class ServerLifetime {
  ServerLifetime({this.startupGrace = defaultStartupGrace})
    : _logic = ServerLifetimeLogic(startupGrace: startupGrace) {
    _binding = _logic.bind()
      ..onOutput<ShutdownCommitted>(
        (committed) => _ended.complete(committed.reason),
      );
  }

  /// How long a fresh server waits for its first connection.
  static const defaultStartupGrace = Duration(seconds: 30);

  final Duration startupGrace;
  final ServerLifetimeLogic _logic;
  late final LogicBlockBinding<ServerLifetimeState> _binding;
  final _ended = Completer<ServerStopReason>();

  /// Completes once shutdown is committed, with why.
  Future<ServerStopReason> get ended => _ended.future;

  /// Whether shutdown is committed, so a new request must be turned away.
  bool get shuttingDown => !_logic.value.admits;

  /// Starts the startup grace.
  void start() => _logic.start();

  /// Counts a request that keeps the server up until [closed].
  void opened() => _logic.input(const ConnectionOpened());

  /// Stops counting a request [opened] counted.
  void closed() => _logic.input(const ConnectionClosed());

  /// Commits shutdown whatever is still open.
  void requestShutdown() => _logic.input(const ShutdownRequested());

  /// Cancels the grace for good, so no timer outlives the server.
  void dispose() {
    _binding.dispose();
    _logic.dispose();
  }
}
