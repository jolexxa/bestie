import 'dart:async';

import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/connection/server_connection_data.dart';
import 'package:built_in_server_client/src/connection/server_connection_input.dart';
import 'package:built_in_server_client/src/connection/server_connection_output.dart';
import 'package:built_in_server_client/src/models/built_in_server_connection.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:built_in_server_client/src/server_api.dart';
import 'package:built_in_server_client/src/server_attacher.dart';
import 'package:built_in_server_client/src/session_leases.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// Where this bestie stands with the server: holding nothing, on its way
/// to the owner session, holding it, letting it go, or done for good.
/// Requests that arrive mid-way wait for the step under way, so a release
/// always finishes before a later attach takes a new session.
@PartOf(BuiltInServerClient)
sealed class ServerConnectionState extends StateLogic<ServerConnectionState> {
  ServerConnectionState() {
    on<AttachRequested>(onAttach);
    on<ReleaseRequested>(onRelease);
    on<CloseRequested>(onClose);
    on<UnloadRequested>(onUnload);
    on<UnloadSettled>(onUnloadSettled);
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

  /// Nothing is held, so nothing is loaded.
  Transition onUnload(UnloadRequested input) {
    input.reply.complete();
    return toSelf();
  }

  Transition onUnloadSettled(UnloadSettled input) {
    input.reply.complete();
    return toSelf();
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

  /// Tells every caller waiting on an attempt how it went.
  void answerAttaches(BuiltInServerConnection connection) {
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
/// ended it, or asking for it failed.
@PartOf(BuiltInServerClient)
final class DisconnectedState extends ServerConnectionState {
  @override
  Transition onAttach(AttachRequested input) {
    awaitAttempt(input);
    return to<AttachingState>();
  }

  /// Nothing is held, so nothing is left to let go.
  @override
  Transition onRelease(ReleaseRequested input) {
    input.reply.complete();
    return toSelf();
  }
}

/// Finding or starting the server and asking it for the owner session.
@PartOf(BuiltInServerClient)
final class AttachingState extends ServerConnectionState {
  AttachingState() {
    onEnter(() {
      final attempt = ++data.attempt;
      output(const ConnectionChanged(BuiltInServerAttaching()));
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
          output(SessionStarted(held.session));
          output(ConnectionChanged(held.attached));
          answerAttaches(held.attached);
          return to<AttachedState>();
        case AttachRefused(:final connection):
          output(ConnectionChanged(connection));
          answerAttaches(connection);
          return to<DisconnectedState>();
      }
    });
  }
}

/// This bestie owns the server: it may lease agents and load models.
@PartOf(BuiltInServerClient)
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
      output(const ConnectionChanged(BuiltInServerDisconnected()));
      return to<DisconnectedState>();
    });
  }

  @override
  Transition onUnloadSettled(UnloadSettled input) {
    if (identical(input.session, data.holding.session)) data.lastLoad = null;
    return super.onUnloadSettled(input);
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

  /// Unloads whatever the server holds, which the next load then loads
  /// afresh.
  @override
  Transition onUnload(UnloadRequested input) {
    final session = data.holding.session;
    async(api.unload(data.holding.attached)).input(
      (_) => UnloadSettled(session: session, reply: input.reply),
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
@PartOf(BuiltInServerClient)
final class ReleasingState extends ServerConnectionState {
  ReleasingState() {
    onEnter(() {
      answerAttaches(const BuiltInServerDisconnected());
      async(_letGo(data.held)).input((_) => const LetGo());
    });

    on<LetGo>((_) {
      data
        ..letGo()
        ..modelStatus = const ModelUnloaded();
      output(const ModelStatusChanged(ModelUnloaded()));
      answerLetGo();
      if (data.attachWaiters.isNotEmpty) return to<AttachingState>();
      output(const ConnectionChanged(BuiltInServerDisconnected()));
      return to<DisconnectedState>();
    });
  }

  @override
  Transition onRelease(ReleaseRequested input) {
    answerAttaches(const BuiltInServerDisconnected());
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
@PartOf(BuiltInServerClient)
final class ClosedState extends ServerConnectionState {
  ClosedState() {
    onEnter(() {
      answerAttaches(const BuiltInServerDisconnected());
      output(const ConnectionChanged(BuiltInServerDisconnected()));
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
    input.reply.complete(const BuiltInServerDisconnected());
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

@PartOf(BuiltInServerClient)
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
