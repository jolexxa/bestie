import 'package:intentions/intentions.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_repository/src/readiness/sandbox_readiness_host.dart';

/// Mutable state shared across the readiness states.
@model
final class SandboxReadinessData {
  SandboxReadinessData({required this.host, required this.preparesHost});

  /// Does the host work each step asks for.
  final SandboxReadinessHost host;

  /// Whether the host has one-time grants to check before it can confine,
  /// so nothing may be acquired until it has been warmed up.
  final bool preparesHost;

  /// The policy the session was warmed for, once it has been.
  SandboxSpec? spec;

  /// Why the last initialization failed, while it stands failed.
  String failure = '';
}
