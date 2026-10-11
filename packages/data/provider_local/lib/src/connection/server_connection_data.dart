import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/local_connection.dart';
import 'package:provider_local/src/models/local_server_connection.dart';
import 'package:provider_local/src/server_attacher.dart';
import 'package:provider_local/src/session_leases.dart';

/// Mutable data shared by the server connection states.
@PartOf(LocalConnection)
final class ServerConnectionData {
  /// The model's status, as the owner session last reported it.
  ModelStatus modelStatus = const ModelUnloaded();

  /// Bumped for every attempt to hold the session, so an attempt that was
  /// let go before it settled is ignored when it does.
  int attempt = 0;

  /// Callers waiting to learn how the next or current attempt went.
  List<Completer<LocalServerConnection>> attachWaiters = [];

  /// Callers waiting for the server to be let go.
  List<Completer<void>> letGoWaiters = [];

  /// The session held, or the attempt under way to hold one.
  Future<AttachOutcome> held = Future.value(_nothingHeld);

  /// The session held while attached.
  late AttachHeld holding;

  /// The leases held over [holding] while attached.
  late SessionLeases leases;

  /// The load [holding] last served, which a repeat of need not reload.
  ModelLoadRequest? lastLoad;

  /// Completes once the session held now is let go.
  Completer<void> detached = Completer<void>()..complete();

  /// Completes once the client has let go of the server for good.
  Future<void> hungUp = Future.value();

  static const _nothingHeld = AttachRefused(LocalServerDisconnected());

  /// Forgets the session, which has been let go.
  void letGo() => held = Future.value(_nothingHeld);
}
