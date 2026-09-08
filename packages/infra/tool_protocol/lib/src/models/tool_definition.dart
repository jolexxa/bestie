import 'package:dart_mappable/dart_mappable.dart';

part 'tool_definition.mapper.dart';

/// A tool an ai model can call.
@MappableClass()
final class ToolDefinition with ToolDefinitionMappable {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    required this.onProgress,
    required this.onSuccess,
    required this.onError,
    this.onBackgrounded = '',
    this.onJobSuccess = '',
    this.onJobError = '',
  });

  /// The tool's unique identifier. This is the name the model emits to invoke
  /// the tool and the key the registry dispatches on.
  final String name;

  /// Natural-language explanation of what the tool does, shown to the model so
  /// it can decide whether and how to call the tool.
  final String description;

  /// JSON Schema (as a decoded map) describing the tool's arguments. Presented
  /// to the model as the shape of the call payload and used to validate it.
  final Map<String, Object?> parameters;

  /// Activity-stub label template shown while the call is running, before a
  /// result arrives, e.g. `'Reading ${path:basename}'`.
  ///
  /// {@template tool_protocol.label_grammar}
  /// Templates are literal text plus `${arg}` / `${arg:modifier}`
  /// substitutions drawn from the call's arguments.
  /// {@endtemplate}
  final String onProgress;

  /// Activity-stub label template shown when the call succeeds, e.g.
  /// `'Read ${path:basename}'`.
  ///
  /// {@macro tool_protocol.label_grammar}
  final String onSuccess;

  /// Activity-stub label template shown when the call fails, e.g.
  /// `'Failed to read ${path:basename}'`.
  ///
  /// {@macro tool_protocol.label_grammar}
  final String onError;

  /// Label template for a job that outlived its call and is still going, e.g.
  /// `'Continuing in background: ${command}'`.
  final String onBackgrounded;

  /// Label template for the report of a job that finished in the background,
  /// e.g. `'Subagent finished: ${title}'`. The other templates describe
  /// starting the work; this one describes its ending. Empty for a tool whose
  /// jobs never outlive their call.
  ///
  /// {@macro tool_protocol.label_grammar}
  final String onJobSuccess;

  /// Label template for the report of a job that failed in the background,
  /// e.g. `'Subagent failed: ${title}'`.
  ///
  /// {@macro tool_protocol.label_grammar}
  final String onJobError;
}
