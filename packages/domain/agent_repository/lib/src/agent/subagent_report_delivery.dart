import 'package:agent_repository/src/agent/agent_session.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

// ── Inputs ──────────────────────────────────────────────────

@model
sealed class JobReportDeliveryInput {
  const JobReportDeliveryInput();
}

/// A background job settled and joins the delivery buffer, already stamped
/// with the label its tool gives a settled job.
@model
final class JobReportSettled extends JobReportDeliveryInput {
  JobReportSettled(this.report);
  final DeliveredJobReport report;
}

/// The active primary session changed (placeholder ⇄ live). Buffered reports
/// retarget onto the current addressed session and get an immediate attempt.
@model
final class AgentBound extends JobReportDeliveryInput {
  AgentBound(this.agent);
  final AgentSession agent;
}

/// The current primary reached an idle edge — a window to drain the buffer.
@model
final class AgentIdled extends JobReportDeliveryInput {
  const AgentIdled();
}

/// The dispatched delivery turn resolved: [accepted] is whether the primary
/// took it. A rejected batch is re-buffered to retry on the next window.
@model
final class DeliveryResolved extends JobReportDeliveryInput {
  DeliveryResolved({required this.accepted});
  final bool accepted;
}

// ── Data ────────────────────────────────────────────────────

@model
final class JobReportDeliveryData {
  final List<DeliveredJobReport> pending = [];
  final List<DeliveredJobReport> inFlight = [];
  AgentSession? agent;
}

// ── States ──────────────────────────────────────────────────

@model
sealed class JobReportDeliveryState extends StateLogic<JobReportDeliveryState> {
  JobReportDeliveryData get data => get<JobReportDeliveryData>();

  void _buffer(JobReportSettled input) {
    data.pending.add(input.report);
  }

  /// Attempts to deliver the buffered reports. With no live primary to take
  /// them the batch parks in the waiting state; otherwise it moves in-flight
  /// and a delivery turn is dispatched. Callers only reach here with a
  /// non-empty buffer — an empty buffer settles to idle instead.
  Transition _dispatch() {
    if (data.agent == null) return to<AwaitingIdleState>();
    data.inFlight
      ..clear()
      ..addAll(data.pending);
    data.pending.clear();
    return to<DeliveringState>();
  }
}

/// Buffer empty, no turn in flight — waiting for the next settled report.
@model
final class IdleDeliveryState extends JobReportDeliveryState {
  IdleDeliveryState() {
    on<JobReportSettled>((input) {
      _buffer(input);
      return _dispatch();
    });
    on<AgentBound>((input) {
      data.agent = input.agent;
      return toSelf();
    });
    on<AgentIdled>((_) => toSelf());
  }
}

/// Reports buffered but the primary can't take them yet (busy, or not live) —
/// waiting for its next idle edge.
@model
final class AwaitingIdleState extends JobReportDeliveryState {
  AwaitingIdleState() {
    on<JobReportSettled>((input) {
      _buffer(input);
      return toSelf();
    });
    on<AgentBound>((input) {
      data.agent = input.agent;
      return _dispatch();
    });
    on<AgentIdled>((_) => _dispatch());
  }
}

/// A delivery turn is in flight. New reports and idle edges just accumulate;
/// only [DeliveryResolved] moves us on, so at most one turn is ever dispatched.
@model
final class DeliveringState extends JobReportDeliveryState {
  DeliveringState() {
    onEnter(() {
      final agent = data.agent!;
      async(
        agent.beginDeliveryTurn(List<DeliveredJobReport>.of(data.inFlight)),
      ).input((accepted) => DeliveryResolved(accepted: accepted));
    });

    on<JobReportSettled>((input) {
      _buffer(input);
      return toSelf();
    });
    on<AgentBound>((input) {
      data.agent = input.agent;
      return toSelf();
    });
    on<AgentIdled>((_) => toSelf());

    on<DeliveryResolved>((input) {
      if (!input.accepted) data.pending.insertAll(0, data.inFlight);
      data.inFlight.clear();

      return data.pending.isEmpty
          ? to<IdleDeliveryState>()
          : to<AwaitingIdleState>();
    });
  }
}

// ── Logic block ─────────────────────────────────────────────

/// Delivers settled subagent reports back to the primary as coalesced follow-up
/// turns.
@model
final class JobReportDeliveryLogic extends LogicBlock<JobReportDeliveryState> {
  JobReportDeliveryLogic() {
    set(JobReportDeliveryData());
    set(IdleDeliveryState());
    set(AwaitingIdleState());
    set(DeliveringState());
  }

  @override
  Transition getInitialState() => to<IdleDeliveryState>();
}
