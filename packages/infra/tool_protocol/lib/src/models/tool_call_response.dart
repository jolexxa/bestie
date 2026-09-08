import 'package:dart_mappable/dart_mappable.dart';
import 'package:tool_protocol/src/models/contribution.dart';

part 'tool_call_response.mapper.dart';

/// What stands between a failure's message and the content told under it.
const String messageSeparator = '\n\n';

/// A terminal answer to one tool call. Its job may continue in the background.
@MappableClass(discriminatorKey: 'type')
sealed class ToolCallResponse with ToolCallResponseMappable {
  const ToolCallResponse({
    required this.callId,
    required this.toolName,
    this.elapsedMs,
  });

  final String callId;
  final String toolName;
  final int? elapsedMs;

  /// Text a formatter or compatibility projection presents to the model.
  String get modelText => switch (this) {
    ToolCallSucceeded(:final content) => content,
    ToolCallFailed(:final message, :final content) =>
      content.isEmpty ? message : '$message$messageSeparator$content',
    ToolCallCanceled(:final message) => message,
  };
}

@MappableClass(discriminatorValue: 'ok')
base class ToolCallSucceeded extends ToolCallResponse
    with ToolCallSucceededMappable {
  const ToolCallSucceeded({
    required super.callId,
    required super.toolName,
    required this.content,
    this.contributions = const [],
    super.elapsedMs,
  });

  final String content;
  final List<Contribution> contributions;
}

/// The call was answered, while its job continues independently.
@MappableClass(discriminatorValue: 'background')
final class ToolCallInBackground extends ToolCallSucceeded
    with ToolCallInBackgroundMappable {
  const ToolCallInBackground({
    required super.callId,
    required super.toolName,
    required super.content,
    super.contributions,
    super.elapsedMs,
  });
}

@MappableClass(discriminatorValue: 'error')
final class ToolCallFailed extends ToolCallResponse
    with ToolCallFailedMappable {
  const ToolCallFailed({
    required super.callId,
    required super.toolName,
    required this.message,
    this.content = '',
    super.elapsedMs,
  });

  final String message;
  final String content;
}

@MappableClass(discriminatorValue: 'canceled')
final class ToolCallCanceled extends ToolCallResponse
    with ToolCallCanceledMappable {
  const ToolCallCanceled({
    required super.callId,
    required super.toolName,
    required this.message,
    super.elapsedMs,
  });

  final String message;
}
