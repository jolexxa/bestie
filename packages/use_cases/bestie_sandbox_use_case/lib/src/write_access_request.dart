import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// An agent's ask, awaiting the user: may its programs write under [path]?
@model
@immutable
final class WriteAccessRequest {
  const WriteAccessRequest({
    required this.id,
    required this.path,
    required this.shownPath,
    required this.reason,
    required this.agentId,
  });

  /// Names this ask for the answer to find it.
  final String id;

  /// The directory asked for, normalized and absolute.
  final String path;

  /// [path] as the user knows it: their home directory shortened to `~`.
  final String shownPath;

  /// The agent's one sentence on why.
  final String reason;

  /// The agent asking.
  final String agentId;

  @override
  bool operator ==(Object other) =>
      other is WriteAccessRequest &&
      other.id == id &&
      other.path == path &&
      other.shownPath == shownPath &&
      other.reason == reason &&
      other.agentId == agentId;

  @override
  int get hashCode => Object.hash(id, path, shownPath, reason, agentId);
}
