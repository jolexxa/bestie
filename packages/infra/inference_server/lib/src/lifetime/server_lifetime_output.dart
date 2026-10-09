import 'package:inference_server/src/lifetime/server_stop_reason.dart';

/// What the server's lifetime decides.
sealed class ServerLifetimeOutput {
  const ServerLifetimeOutput();
}

/// The server stops for [reason]; nothing it takes on from here keeps it up.
final class ShutdownCommitted extends ServerLifetimeOutput {
  const ShutdownCommitted(this.reason);

  final ServerStopReason reason;
}
