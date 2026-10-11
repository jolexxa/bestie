import 'dart:async';

/// The connections a server holds, and the grace it gives a first one.
final class ServerLifetimeData {
  int connections = 0;

  Timer? grace;
}
