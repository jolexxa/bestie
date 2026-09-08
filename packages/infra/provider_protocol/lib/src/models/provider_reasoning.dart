import 'package:dart_mappable/dart_mappable.dart';

part 'provider_reasoning.mapper.dart';

/// How a model thinks and which controls the provider accepts for it.
@MappableClass(discriminatorKey: 'kind')
sealed class ProviderReasoning with ProviderReasoningMappable {
  const ProviderReasoning();
}

/// The model always thinks and offers no control over it.
@MappableClass(discriminatorValue: 'fixed')
final class ProviderReasoningFixed extends ProviderReasoning
    with ProviderReasoningFixedMappable {
  const ProviderReasoningFixed();
}

/// Thinking can be switched on or off, nothing finer.
@MappableClass(discriminatorValue: 'toggle')
final class ProviderReasoningToggle extends ProviderReasoning
    with ProviderReasoningToggleMappable {
  const ProviderReasoningToggle({this.enabledByDefault});

  /// Whether the model thinks when the request does not ask either way.
  final bool? enabledByDefault;
}

/// Thinking is chosen from named effort levels.
@MappableClass(discriminatorValue: 'efforts')
final class ProviderReasoningEfforts extends ProviderReasoning
    with ProviderReasoningEffortsMappable {
  const ProviderReasoningEfforts({
    required this.efforts,
    required this.canDisable,
    this.defaultEffort,
  });

  /// Accepted effort names, cheapest first.
  final List<String> efforts;

  /// Whether the model may be asked not to think at all.
  final bool canDisable;

  /// The effort used when the request does not name one.
  final String? defaultEffort;
}
