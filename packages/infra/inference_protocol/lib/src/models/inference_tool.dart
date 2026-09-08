import 'package:meta/meta.dart';

/// A function the model may call, described with a JSON schema.
@immutable
final class InferenceTool {
  const InferenceTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;

  final String description;

  /// JSON schema for the arguments object.
  final Map<String, Object?> parameters;
}
