import 'package:meta/meta.dart';

/// A complete tool invocation requested by the model.
@immutable
final class InferenceToolCall {
  const InferenceToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    required this.rawArguments,
  });

  /// Provider-assigned id that the tool result must echo back.
  final String id;

  final String name;

  /// Parsed arguments; empty when [rawArguments] was not valid JSON.
  final Map<String, Object?> arguments;

  /// The argument text exactly as the model produced it.
  final String rawArguments;

  @override
  bool operator ==(Object other) =>
      other is InferenceToolCall &&
      other.id == id &&
      other.name == name &&
      other.rawArguments == rawArguments;

  @override
  int get hashCode => Object.hash(id, name, rawArguments);

  @override
  String toString() => 'InferenceToolCall($id, $name, $rawArguments)';
}
