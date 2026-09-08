import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

part 'job_in_background.mapper.dart';

/// Persistable projection of a router-produced [JobBackgrounded].
@model
@MappableClass()
final class JobInBackground with JobInBackgroundMappable {
  const JobInBackground({
    required this.callId,
    required this.toolName,
    this.labelTemplate = '',
    this.labelArguments = const {},
  });

  /// Stamps [job] with the label [definition] gives work in progress. Stamping
  /// denormalizes the label onto the transcript, so the row still reads
  /// correctly after the tool's templates change or the tool is removed.
  factory JobInBackground.fromJobBackgrounded(
    JobBackgrounded job, {
    ToolDefinition? definition,
  }) {
    final template = switch (definition) {
      null => '',
      ToolDefinition(:final onBackgrounded) when onBackgrounded.isNotEmpty =>
        onBackgrounded,
      final d => d.onProgress,
    };
    return JobInBackground(
      callId: job.callId,
      toolName: job.toolName,
      labelTemplate: template,
      labelArguments: labelArgumentsFor(template, job.arguments),
    );
  }

  final String callId;
  final String toolName;

  /// Label template for this job, or empty when its tool declares none.
  final String labelTemplate;

  /// Only the arguments [labelTemplate] substitutes.
  final Map<String, Object?> labelArguments;
}
