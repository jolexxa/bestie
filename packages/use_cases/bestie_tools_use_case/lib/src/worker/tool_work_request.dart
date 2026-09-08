import 'package:bestie_tools_use_case/src/utility_tools_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// One tool call handed to a worker, with the confinement any program it
/// spawns has to run under.
@PartOf(UtilityToolsUseCase)
final class ToolWorkRequest {
  const ToolWorkRequest(this.invocation, {this.sandbox});

  final ToolCallInvocation invocation;

  /// Absent when the call runs unconfined.
  final Sandbox? sandbox;
}
