import 'dart:async';

import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/models/disconnect_cause.dart';
import 'package:built_in_server_client/src/server_attacher.dart';
import 'package:built_in_server_client/src/session_leases.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';

/// Mutable data shared by the server connection states.
@PartOf(BuiltInServerClient)
final class ServerConnectionData {
  /// The model's status, as the owner session last reported it.
  ModelStatus modelStatus = const ModelUnloaded();

  /// Bumped for every attempt to hold the session, so an attempt that was
  /// let go before it settled is ignored when it does.
  int attempt = 0;

  /// Callers waiting to learn how the next or current attempt went.
  List<Completer<BuiltInServerConnection>> attachWaiters = [];

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

  /// Why the server said it would end [holding], if it said so.
  ServerStopReason? closing;

  /// Completes with why once the session held now is let go.
  Completer<DisconnectCause> detached = Completer<DisconnectCause>()
    ..complete(const NotYetAttached());

  /// Completes once the client has let go of the server for good.
  Future<void> hungUp = Future.value();

  static const _nothingHeld = AttachRefused(BuiltInServerDisconnected());

  /// Forgets the session, which has been let go.
  void letGo() => held = Future.value(_nothingHeld);

  /// Tells whoever waits on the session held now that it is gone for
  /// [cause], unless they were already told.
  void settleDetached(DisconnectCause cause) {
    if (!detached.isCompleted) detached.complete(cause);
  }
}
