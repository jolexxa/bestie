import 'package:intentions/intentions.dart';
import 'package:shell_repository/src/session/shell_session.dart';

/// Coarse lifecycle of a session, for roster rows that do not want to
/// pattern-match the full state.
@model
enum ShellSessionStatus {
  /// The spawn is in flight.
  starting,

  /// The child is alive.
  running,

  /// The child terminated; its transcript is still readable.
  exited,

  /// The spawn was refused, so there is no child.
  failed,
}

/// A lightweight roster row: enough to render a tab or list entry without
/// holding the session itself. Fetch the full session by [id] to render it.
@model
final class ShellSessionSummary {
  const ShellSessionSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.kind,
  });

  /// The session this row describes.
  final ShellSessionId id;

  /// Display label: whatever the child set via OSC, else what was launched.
  final String title;

  /// Coarse lifecycle status.
  final ShellSessionStatus status;

  /// Which lifecycle the session follows.
  final ShellSessionKind kind;
}
