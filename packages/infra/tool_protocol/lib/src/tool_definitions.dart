import 'package:tool_protocol/src/models/tool_definition.dart';

/// The tools a model is told it may call.
class ToolDefinitions {
  ToolDefinitions([List<ToolDefinition> definitions = const []])
    : _definitions = List.unmodifiable(definitions),
      _byName = {
        for (final definition in definitions) definition.name: definition,
      };

  final List<ToolDefinition> _definitions;
  final Map<String, ToolDefinition> _byName;

  /// Every definition, in the order they were declared.
  List<ToolDefinition> get definitions => _definitions;

  /// The definition for [name], or null when no tool here goes by it.
  ToolDefinition? definitionFor(String name) => _byName[name];
}
