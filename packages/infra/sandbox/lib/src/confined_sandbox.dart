import 'package:process_host/process_host.dart';
import 'package:sandbox/src/sandbox_enforcement.dart';

/// A [Sandbox] that knows what it enforces.
abstract interface class ConfinedSandbox implements Sandbox {
  /// The restrictions this sandbox holds.
  SandboxEnforcement get enforcement;
}
