import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';

part 'sandbox_read_grant.mapper.dart';

/// The applied state of the shared bestie-read capability: the roots ACL'd to
/// it for broad read, the secret holes carved out, and the [policyVersion] that
/// produced them.
@model
@MappableClass()
final class SandboxReadGrant with SandboxReadGrantMappable {
  const SandboxReadGrant({
    required this.capabilitySid,
    required this.readRoots,
    required this.holes,
    required this.policyVersion,
  });

  final String capabilitySid;
  final List<String> readRoots;
  final List<String> holes;
  final int policyVersion;
}
