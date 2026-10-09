import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/server_attacher.dart';
import 'package:local_inference_client/src/session_leases.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// Mutable data shared by the server connection states.
@PartOf(LocalInferenceClient)
final class ServerConnectionData {
  /// Where this bestie stands with the server, as last published.
  LocalServerConnection connection = const LocalServerDisconnected();

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
