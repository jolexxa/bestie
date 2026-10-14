import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// One tool call handed to a worker, with the confinement any program it
/// spawns has to run under.
@model
final class ToolWorkRequest {
  const ToolWorkRequest(this.invocation, {this.sandbox});

  final ToolCallInvocation invocation;

  /// Absent when the call runs unconfined.
  final Sandbox? sandbox;
}

/// What a queued tool call turned out to need once it could be prepared.
@model
sealed class ToolWorkStart {
  const ToolWorkStart();
}

/// The call is ready to hand to a worker.
@model
final class ToolWorkReady extends ToolWorkStart {
  const ToolWorkReady(this.request);

  final ToolWorkRequest request;
}

/// The call cannot run, and [message] says why.
@model
final class ToolWorkRefused extends ToolWorkStart {
  const ToolWorkRefused(this.message);

  final String message;
}
