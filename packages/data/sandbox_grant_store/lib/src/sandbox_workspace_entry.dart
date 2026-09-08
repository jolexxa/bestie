import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';

part 'sandbox_workspace_entry.mapper.dart';

/// A workspace whose write grants have been applied to its per-workspace
/// package SID: the workspace itself, plus [widenedRoots] beyond it.
@model
@MappableClass()
final class SandboxWorkspaceEntry with SandboxWorkspaceEntryMappable {
  const SandboxWorkspaceEntry({
    required this.workspaceRoot,
    required this.profileName,
    required this.containerSid,
    required this.lastSeen,
    this.widenedRoots = const [],
  });

  final String workspaceRoot;
  final String profileName;
  final String containerSid;
  final DateTime lastSeen;

  /// The directories beyond the workspace the container was granted write on.
  final List<String> widenedRoots;
}
