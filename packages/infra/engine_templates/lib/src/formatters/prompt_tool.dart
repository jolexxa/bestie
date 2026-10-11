/// A tool the prompt tells the model it may call.
final class PromptTool {
  const PromptTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;

  final String description;

  /// The JSON schema of the tool's arguments.
  final Map<String, Object?> parameters;
}
