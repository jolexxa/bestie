import 'package:dart_mappable/dart_mappable.dart';

part 'model_reasoning.mapper.dart';

/// Whether a model thinks and how a request can steer it.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorKey: 'kind')
sealed class ModelReasoning with ModelReasoningMappable {
  const ModelReasoning();
}

/// The model never thinks.
@MappableClass(discriminatorValue: 'none')
final class ModelReasoningNone extends ModelReasoning
    with ModelReasoningNoneMappable {
  const ModelReasoningNone();
}

/// Thinking can be switched on or off.
@MappableClass(discriminatorValue: 'toggle')
final class ModelReasoningToggle extends ModelReasoning
    with ModelReasoningToggleMappable {
  const ModelReasoningToggle();
}

/// Thinking is chosen from named effort levels.
@MappableClass(discriminatorValue: 'efforts')
final class ModelReasoningEfforts extends ModelReasoning
    with ModelReasoningEffortsMappable {
  const ModelReasoningEfforts({required this.efforts});

  /// Accepted effort names, cheapest first.
  final List<String> efforts;
}

/// The model always thinks.
@MappableClass(discriminatorValue: 'always')
final class ModelReasoningAlways extends ModelReasoning
    with ModelReasoningAlwaysMappable {
  const ModelReasoningAlways();
}
