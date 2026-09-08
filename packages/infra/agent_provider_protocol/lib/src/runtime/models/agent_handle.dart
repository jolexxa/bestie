enum AgentKind { primary, subagent }

final class AgentHandle {
  const AgentHandle({required this.id, required this.kind, this.label});

  final String id;
  final AgentKind kind;
  final String? label;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentHandle && other.id == id && other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(id, kind);
}
