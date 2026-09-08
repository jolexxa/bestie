import 'dart:async';

import 'package:bestie_tools_use_case/src/routing/tool_router.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Feature use case for the tool system: it takes the calls a [ToolRequester]
/// makes, hands each to the feature that owns that tool, and owns every job
/// those calls become until it settles.
///
/// A call whose job outlives the call it came from is reported back to the
/// requester rather than answered in place, so the tools a conversation
/// started keep running while the conversation moves on.
@useCase
class ToolsUseCase implements CommandContribution {
  ToolsUseCase({
    required ToolRequester agents,
    required List<ToolResponder> responders,
  }) : _router = ToolRouter(requester: agents, responders: responders) {
    commands = List.unmodifiable([
      Command(
        id: 'tools.stopJobs',
        title: 'Stop all jobs',
        glyph: '▣',
        shortcut: 'Esc',
        description: 'Cancel every background tool job',
        group: 'Tools',
        availability: _stopJobsAvailability(),
        invoke: _stopAllJobs,
      ),
    ]);
  }

  final ToolRouter _router;

  @override
  late final List<Command> commands;

  /// How many jobs are unsettled, re-emitted whenever that changes.
  Stream<int> get activeJobs => _router.jobs.map((entries) => entries.length);

  /// The unsettled job count right now.
  int get activeJobCount => _router.entries.length;

  /// Stops every job, wherever it runs — pending-call and background alike.
  void stopJobs() => _router.stopAllJobs();

  Future<void> dispose() => _router.dispose();

  /// Seeds the current job count on listen, then follows every change, so
  /// the palette gates the command correctly however late it subscribes.
  Stream<Availability> _stopJobsAvailability() =>
      gatedAvailability(() => activeJobCount, activeJobs, _gateOnJobs);

  static Availability _gateOnJobs(int count) =>
      count > 0 ? const Available() : const Unavailable('no active jobs');

  Future<CommandResult> _stopAllJobs(Answers answers) async {
    if (activeJobCount == 0) return const CommandRejected('no active jobs');
    stopJobs();
    return const CommandRan();
  }
}
