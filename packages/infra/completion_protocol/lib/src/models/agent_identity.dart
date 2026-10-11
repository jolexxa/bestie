import 'package:meta/meta.dart';

/// Whether an agent leads a conversation or works for the one that does.
enum AgentIdentityKind { primary, subagent }

/// Which agent a completion or a session belongs to, so an endpoint that
/// keeps per-agent state can route to it.
@immutable
final class AgentIdentity {
  const AgentIdentity({required this.id, required this.kind});

  final String id;

  final AgentIdentityKind kind;

  @override
  bool operator ==(Object other) =>
      other is AgentIdentity && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'AgentIdentity($id, ${kind.name})';
}
