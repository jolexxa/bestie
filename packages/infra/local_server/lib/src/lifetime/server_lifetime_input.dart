import 'package:local_server_protocol/local_server_protocol.dart';

/// What the server's lifetime hears about.
sealed class ServerLifetimeInput {
  const ServerLifetimeInput();
}

/// A request that keeps the server up was taken on.
final class ConnectionOpened extends ServerLifetimeInput {
  const ConnectionOpened();
}

/// A request that kept the server up has been answered, or its client hung
/// up.
final class ConnectionClosed extends ServerLifetimeInput {
  const ConnectionClosed();
}

/// The startup grace ran out.
final class GraceExpired extends ServerLifetimeInput {
  const GraceExpired();
}

/// The server must stop for [reason], whatever is still open.
final class ShutdownRequested extends ServerLifetimeInput {
  const ShutdownRequested(this.reason);

  final ServerStopReason reason;
}
