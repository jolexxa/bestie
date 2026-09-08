import 'package:dart_mappable/dart_mappable.dart';

part 'tool_call.mapper.dart';

@MappableClass(discriminatorKey: 'type')
sealed class ToolCall with ToolCallMappable {
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

@MappableClass(discriminatorValue: 'default')
final class ToolCallDefault extends ToolCall with ToolCallDefaultMappable {
  const ToolCallDefault({
    required super.id,
    required super.name,
    required super.arguments,
  });
}

@MappableClass(discriminatorValue: 'reasoning')
final class ToolCallReasoning extends ToolCall with ToolCallReasoningMappable {
  const ToolCallReasoning({
    required super.id,
    required super.name,
    required super.arguments,
  });
}
