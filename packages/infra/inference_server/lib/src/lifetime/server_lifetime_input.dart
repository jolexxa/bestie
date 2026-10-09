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

/// The process was asked to stop.
final class ShutdownRequested extends ServerLifetimeInput {
  const ShutdownRequested();
}
