import 'package:tool_protocol/src/models/job_backgrounded.dart';
import 'package:tool_protocol/src/models/job_report.dart';
import 'package:tool_protocol/src/tool_call_request.dart';

/// The side that makes tool calls and takes back what became of them.
abstract interface class ToolRequester {
  Stream<ToolCallRequest> get toolRequests;

  /// A call has been answered but its work goes on.
  void noteBackgrounded(JobBackgrounded job);

  void deliverReport(JobReport report);
}
