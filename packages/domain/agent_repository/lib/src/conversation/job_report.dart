import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

part 'job_report.mapper.dart';

/// Persistable projection of a router-produced [JobReport].
@model
@MappableClass()
final class DeliveredJobReport with DeliveredJobReportMappable {
  const DeliveredJobReport({
    required this.callId,
    required this.toolName,
    required this.succeeded,
    required this.body,
    required this.outstanding,
    this.labelTemplate = '',
    this.labelArguments = const {},
  });

  /// Stamps [report] with the label [definition] gives a settled job, keeping
  /// only the arguments that label substitutes. Stamping denormalizes the
  /// label onto the transcript, so the row still reads correctly after the
  /// originating call is compacted away or the tool's templates change.
  factory DeliveredJobReport.fromJobReport(
    JobReport report, {
    ToolDefinition? definition,
  }) {
    final succeeded = report.outcome is JobSucceeded;
    final template = switch (definition) {
      null => '',
      final d => succeeded ? d.onJobSuccess : d.onJobError,
    };
    return DeliveredJobReport(
      callId: report.callId,
      toolName: report.toolName,
      succeeded: succeeded,
      body: switch (report.outcome) {
        JobSucceeded(:final content) => content,

        JobFailed(:final message, :final content) =>
          content.isEmpty ? message : '$message\n\n$content',
      },
      outstanding: report.outstanding,
      labelTemplate: template,
      labelArguments: labelArgumentsFor(template, report.arguments),
    );
  }

  final String callId;
  final String toolName;
  final bool succeeded;
  final String body;
  final int outstanding;

  /// Label template for this report, or empty when its tool declares none.
  final String labelTemplate;

  /// Only the arguments [labelTemplate] substitutes.
  final Map<String, Object?> labelArguments;
}

const jobReportPreamble = '<!-- Automated job report, not from the user. -->';

/// Renders a coalesced delivery batch as one unsolicited user message.
String composeJobReportText(List<DeliveredJobReport> reports) {
  final buffer = StringBuffer(jobReportPreamble);
  for (final report in reports) {
    buffer
      ..write('\n\n<job id="${report.callId}" tool="${report.toolName}" ')
      ..write('status="${report.succeeded ? 'success' : 'failure'}">\n')
      ..write(report.body)
      ..write('\n</job>');
  }
  final outstanding = reports.isEmpty ? 0 : reports.last.outstanding;
  if (outstanding > 0) {
    buffer.write(
      '\n\n<pending>$outstanding job${outstanding == 1 ? "" : "s"} '
      'still pending, will notify on completion.</pending>',
    );
  }
  return buffer.toString();
}
