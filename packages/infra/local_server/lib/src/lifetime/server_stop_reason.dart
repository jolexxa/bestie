/// Why a server stopped.
enum ServerStopReason {
  /// Its last connection closed.
  drained,

  /// Nothing connected within the startup grace.
  unclaimed,

  /// The process was asked to stop.
  requested,
}
