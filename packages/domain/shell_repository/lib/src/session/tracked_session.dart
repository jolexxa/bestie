import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:shell_repository/src/session/shell_session.dart';
import 'package:shell_repository/src/session/shell_session_logic.dart';
import 'package:shell_repository/src/session/shell_session_summary.dart';
import 'package:shell_repository/src/shell_repository.dart';

/// One session plus the subscriptions keeping the roster current.
@PartOf(ShellRepository)
class TrackedSession {
  TrackedSession({
    required this.session,
    required this.stateSub,
    required this.titleSub,
  });

  final ShellSession session;
  final StreamSubscription<ShellSessionState> stateSub;
  final StreamSubscription<String> titleSub;

  ShellSessionSummary get summary => ShellSessionSummary(
    id: session.id,
    title: session.title,
    status: _status,
    kind: session.kind,
  );

  ShellSessionStatus get _status => switch (session.state) {
    ShellSessionRunning() => ShellSessionStatus.running,
    ShellSessionExited() => ShellSessionStatus.exited,
    ShellSessionStarting() => ShellSessionStatus.starting,
    // A session is started the moment it is opened, so this state is only
    // reached again by a refused spawn.
    ShellSessionNotStarted(:final failure) =>
      failure == null ? ShellSessionStatus.starting : ShellSessionStatus.failed,
  };

  Future<void> release() async {
    await stateSub.cancel();
    await titleSub.cancel();
    await session.dispose();
  }
}
