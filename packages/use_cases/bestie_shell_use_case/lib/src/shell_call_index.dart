import 'dart:async';

import 'package:bestie_shell_use_case/src/agent_shell_attachment.dart';
import 'package:bestie_shell_use_case/src/shell_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Maps each agent shell to the tool call that ran it.
@PartOf(ShellUseCase)
final class ShellCallIndex {
  ShellCallIndex(this._repository);

  final ShellRepository _repository;

  /// The live shell each unfinished call runs in.
  final _live = BehaviorSubject<Map<String, EphemeralShell>>.seeded(const {});

  /// Where each call wrote, by the call id that addresses it.
  final Map<String, String> _outputs = {};

  /// The conversation [_outputs] describes.
  String? _conversation;

  /// Remembers that [invocation] is running in [session], and where it writes,
  /// then drops the live shell the moment its record settles.
  void attach(ToolCallInvocation invocation, EphemeralShell session) {
    final callId = invocation.callId;
    _outputs[callId] = invocation.outputPath;
    _live.add({..._live.value, callId: session});
    unawaited(
      session.transcriptPage.whenComplete(() {
        if (_live.isClosed) return;
        _live.add({..._live.value}..remove(callId));
      }),
    );
  }

  /// Where the call [callId] wrote, or null for a call this never ran.
  String? pathOf(String callId) => _outputs[callId];

  /// Drops an earlier conversation's calls once a call from another arrives.
  void forget({required String before}) {
    if (_conversation == before) return;
    _conversation = before;
    _outputs.clear();
  }

  /// What the call [callId] has to show: the live shell while it runs, then a
  /// record read and parsed off the main isolate once it settles.
  Stream<AgentShellAttachment> watch(String callId) => _live
      .map((shells) => shells[callId])
      .distinct(identical)
      .switchMap((session) => _attachmentsFor(callId, session));

  Stream<AgentShellAttachment> _attachmentsFor(
    String callId,
    EphemeralShell? session,
  ) async* {
    if (session != null) {
      yield AgentShellLive(session);
      return;
    }
    final path = _outputs[callId];
    if (path == null) {
      yield const AgentShellNone();
      return;
    }
    // Show the terminal chrome at once; the parse it fills with happens off the
    // main isolate, so a long transcript never blocks a frame.
    yield const AgentShellLoading();
    yield AgentShellReplay(await _repository.recordedShellFor(path));
  }

  Future<void> dispose() async {
    _outputs.clear();
    await _live.close();
  }
}
