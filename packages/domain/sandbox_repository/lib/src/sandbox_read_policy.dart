import 'package:intentions/intentions.dart';

/// The desired broad-read policy for the shared bestie-read capability: the
/// roots granted RX and the secret subpaths carved out. [policyVersion] bumps
/// when the set changes.
@model
class SandboxReadPolicy {
  const SandboxReadPolicy({
    required this.readRoots,
    required this.holes,
    required this.policyVersion,
  });

  final List<String> readRoots;
  final List<String> holes;
  final int policyVersion;
}
