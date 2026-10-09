import 'dart:async';

import 'package:inference_protocol/inference_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/connection/server_connection_data.dart';
import 'package:local_inference_client/src/connection/server_connection_input.dart';
import 'package:local_inference_client/src/connection/server_connection_output.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/models/local_server_connection.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_client/src/server_api.dart';
import 'package:local_inference_client/src/server_attacher.dart';
import 'package:local_inference_client/src/session_leases.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// Where this bestie stands with the server: holding nothing, on its way
/// to the owner session, holding it, letting it go, or done for good.
/// Requests that arrive mid-way wait for the step under way, so a release
/// always finishes before a later attach takes a new session.
@PartOf(LocalInferenceClient)
sealed class ServerConnectionState extends StateLogic<ServerConnectionState> {
  ServerConnectionState() {
    on<AttachRequested>(onAttach);
    on<ReleaseRequested>(onRelease);
    on<CloseRequested>(onClose);
    on<LoadRequested>(onLoad);
    on<LeaseOpenRequested>(onLeaseOpen);
    on<LeaseCloseRequested>(onLeaseClose);
  }

  ServerConnectionData get data => get<ServerConnectionData>();
  ServerAttacher get attacher => get<ServerAttacher>();
  ServerApi get api => get<ServerApi>();

  Transition onAttach(AttachRequested input) {
    awaitAttempt(input);
    return toSelf();
  }

  Transition onRelease(ReleaseRequested input) {
    data.letGoWaiters.add(input.reply);
    return to<ReleasingState>();
  }

  Transition onClose(CloseRequested input) {
    data.letGoWaiters.add(input.reply);
    return to<ClosedState>();
  }

  Transition onLoad(LoadRequested input) {
    input.reply.complete(const ModelLoadFailed(notAttached));
    return toSelf();
  }

  Transition onLeaseOpen(LeaseOpenRequested input) {
    input.reply.complete(const AgentSessionFailed(message: notAttached));
    return toSelf();
  }

  /// Nothing is held, so nothing is left to close.
  Transition onLeaseClose(LeaseCloseRequested input) {
    input.reply.complete();
    return toSelf();
  }

  /// Has [input] wait for the attempt under way, or the next one.
  void awaitAttempt(AttachRequested input) =>
      data.attachWaiters.add(input.reply);

  void publish(LocalServerConnection connection) {
    data.connection = connection;
    output(ConnectionChanged(connection));
  }

  /// Tells every caller waiting on an attempt how it went.
  void answerAttaches(LocalServerConnection connection) {
    for (final waiter in data.attachWaiters) {
      waiter.complete(connection);
    }
    data.attachWaiters = [];
  }

  /// Tells every caller waiting for the server to be let go that it is.
  void answerLetGo() {
    for (final waiter in data.letGoWaiters) {
      waiter.complete();
    }
    data.letGoWaiters = [];
  }

  static const notAttached = 'This bestie does not hold the local server.';
}

/// No session is held: none was asked for yet, it was let go, the server
/// ended it, or asking for it failed for the reason the connection gives.
@PartOf(LocalInferenceClient)
final class DisconnectedState extends ServerConnectionState {
  @override
  Transition onAttach(AttachRequested input) {
    awaitAttempt(input);
    return to<AttachingState>();
  }

  /// Forgets why the last attempt failed.
  @override
  Transition onRelease(ReleaseRequested input) {
    final settled = switch (data.connection) {
      LocalServerDisconnected(reason: null) => true,
      _ => false,
    };
    if (!settled) publish(const LocalServerDisconnected());
    input.reply.complete();
    return toSelf();
  }
}

/// Finding or starting the server and asking it for the owner session.
@PartOf(LocalInferenceClient)
final class AttachingState extends ServerConnectionState {
  AttachingState() {
    onEnter(() {
      final attempt = ++data.attempt;
      publish(const LocalServerAttaching());
      data.held = attacher.attach();
      async(data.held).input(
        (outcome) => AttachSettled(attempt: attempt, outcome: outcome),
      );
    });

    on<AttachSettled>((input) {
      if (input.attempt != data.attempt) return toSelf();
      switch (input.outcome) {
        case final AttachHeld held:
          data
            ..holding = held
            ..leases = SessionLeases(api: api, owner: held.attached);
          publish(held.attached);
          output(SessionStarted(held.session));
          answerAttaches(held.attached);
          return to<AttachedState>();
        case AttachRefused(:final connection):
          publish(connection);
          answerAttaches(connection);
          return to<DisconnectedState>();
      }
    });
  }
}

/// This bestie owns the server: it may lease agents and load models.
@PartOf(LocalInferenceClient)
final class AttachedState extends ServerConnectionState {
  AttachedState() {
    onEnter(() => data.detached = Completer<void>());
    onExit(() {
      data
        ..lastLoad = null
        ..detached.complete();
    });

    on<LoadSettled>((input) {
      if (identical(input.session, data.holding.session)) {
        data.lastLoad = input.result is ModelLoaded ? input.request : null;
      }
      return toSelf();
    });

    on<ModelStatusReported>((input) {
      if (!identical(input.session, data.holding.session)) return toSelf();
      data.modelStatus = input.status;
      output(ModelStatusChanged(input.status));
      return toSelf();
    });

    on<SessionEnded>((input) {
      if (!identical(input.session, data.holding.session)) return toSelf();
      async(input.session.close());
      data.letGo();
      publish(
        const LocalServerDisconnected(
          reason: 'The local model server ended the session.',
        ),
      );
      return to<DisconnectedState>();
    });
  }

  @override
  Transition onAttach(AttachRequested input) {
    input.reply.complete(data.holding.attached);
    return toSelf();
  }

  /// Answers at once when the model already serves exactly [input]'s
  /// request.
  @override
  Transition onLoad(LoadRequested input) {
    final request = input.request;
    if (data.modelStatus case final ModelReady ready
        when ready.localId == request.localId && request == data.lastLoad) {
      input.reply.complete(ModelLoaded(ready));
      return toSelf();
    }
    final session = data.holding.session;
    final loading = api.load(data.holding.attached, request);
    input.reply.complete(loading);
    async(loading).input(
      (result) =>
          LoadSettled(session: session, request: request, result: result),
    );
    return toSelf();
  }

  @override
  Transition onLeaseOpen(LeaseOpenRequested input) {
    input.reply.complete(data.leases.open(input.holder, input.agent));
    return toSelf();
  }

  @override
  Transition onLeaseClose(LeaseCloseRequested input) {
    input.reply.complete(switch (input.agentId) {
      final agentId? => data.leases.close(input.holder, agentId),
      null => data.leases.closeAll(input.holder),
    });
    return toSelf();
  }
}

/// Unloading the model and hanging up, or abandoning the attempt under
/// way. Attaches asked for meanwhile take a new session afterwards; a
/// later release drops them.
@PartOf(LocalInferenceClient)
final class ReleasingState extends ServerConnectionState {
  ReleasingState() {
    onEnter(() {
      publish(const LocalServerDisconnected());
      answerAttaches(const LocalServerDisconnected());
      async(_letGo(data.held)).input((_) => const LetGo());
    });

    on<LetGo>((_) {
      data
        ..letGo()
        ..modelStatus = const ModelUnloaded();
      output(const ModelStatusChanged(ModelUnloaded()));
      answerLetGo();
      return data.attachWaiters.isEmpty
          ? to<DisconnectedState>()
          : to<AttachingState>();
    });
  }

  @override
  Transition onRelease(ReleaseRequested input) {
    answerAttaches(const LocalServerDisconnected());
    data.letGoWaiters.add(input.reply);
    return toSelf();
  }

  Future<void> _letGo(Future<AttachOutcome> held) async {
    if (await held case AttachHeld(:final session, :final attached)) {
      await api.unload(attached);
      await session.close();
    }
  }
}

/// The client is spent: whatever was held is hung up, so the server frees
/// every lease at once, and nothing is held again.
@PartOf(LocalInferenceClient)
final class ClosedState extends ServerConnectionState {
  ClosedState() {
    onEnter(() {
      publish(const LocalServerDisconnected());
      answerAttaches(const LocalServerDisconnected());
      data.hungUp = _hangUp(data.held);
      async(data.hungUp).input((_) => const HungUp());
    });

    on<HungUp>((_) {
      answerLetGo();
      return toSelf();
    });
  }

  @override
  Transition onAttach(AttachRequested input) {
    input.reply.complete(const LocalServerDisconnected());
    return toSelf();
  }

  @override
  Transition onRelease(ReleaseRequested input) {
    input.reply.complete(data.hungUp);
    return toSelf();
  }

  @override
  Transition onClose(CloseRequested input) {
    input.reply.complete(data.hungUp);
    return toSelf();
  }

  static Future<void> _hangUp(Future<AttachOutcome> held) async {
    if (await held case AttachHeld(:final session)) await session.close();
  }
}

@PartOf(LocalInferenceClient)
final class ServerConnectionLogic extends LogicBlock<ServerConnectionState> {
  ServerConnectionLogic({
    required ServerAttacher attacher,
    required ServerApi api,
  }) {
    set(ServerConnectionData());
    set(attacher);
    set(api);

    set(DisconnectedState());
    set(AttachingState());
    set(AttachedState());
    set(ReleasingState());
    set(ClosedState());
  }

  @override
  Transition getInitialState() => to<DisconnectedState>();
}
