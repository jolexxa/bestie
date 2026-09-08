import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:sandbox_grant_store/src/sandbox_read_grant.dart';
import 'package:sandbox_grant_store/src/sandbox_workspace_entry.dart';

part 'sandbox_grants.mapper.dart';

/// The whole persisted document: the shared read capability's applied state
/// (null until first granted) and one entry per provisioned workspace.
@model
@MappableClass()
final class SandboxGrants with SandboxGrantsMappable {
  const SandboxGrants({this.read, this.workspaces = const []});

  final SandboxReadGrant? read;
  final List<SandboxWorkspaceEntry> workspaces;
}
