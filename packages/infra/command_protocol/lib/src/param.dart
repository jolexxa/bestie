import 'dart:async';

import 'package:command_protocol/src/option_filter.dart';
import 'package:command_protocol/src/param_key.dart';
import 'package:meta/meta.dart';

/// One selectable value in a choice picker.
@immutable
final class Option<T> {
  const Option({
    required this.value,
    required this.label,
    this.detail,
    String? keywords,
  }) : keywords = keywords ?? label;

  final T value;
  final String label;

  /// Optional secondary line shown under the label.
  final String? detail;

  /// What a picker matches typed queries against; the label alone unless
  /// the command wants more to be findable.
  final String keywords;
}

/// Abstract parameter kinds a command may collect.
sealed class Param {
  const Param({required this.label});

  final String label;

  ParamKey<Object?> get key;
}

/// Free-form text input.
final class TextParam extends Param {
  const TextParam({
    required this.key,
    required super.label,
    this.hint,
    this.validate,
  });

  @override
  final ParamKey<String> key;

  final String? hint;

  /// Returns a problem description for the entered value, or null when valid.
  final String? Function(String value)? validate;
}

/// Numeric input.
final class NumberParam<T extends num> extends Param {
  const NumberParam({
    required this.key,
    required super.label,
    this.min,
    this.max,
  });

  @override
  final ParamKey<T> key;

  final T? min;
  final T? max;
}

/// A yes/no confirmation gate, typically guarding a destructive command.
final class ConfirmParam extends Param {
  const ConfirmParam({
    required this.key,
    required super.label,
    this.danger = false,
  });

  @override
  final ParamKey<bool> key;

  /// Whether to style the prompt as destructive (e.g. the theme error color).
  final bool danger;
}

/// Single selection from a list of options.
final class ChoiceParam<T> extends Param {
  const ChoiceParam({
    required this.key,
    required super.label,
    required this.options,
    this.filter = const FuzzyFilter(),
  });

  /// Convenience for a fixed option list; re-listenable.
  ChoiceParam.fixed({
    required this.key,
    required super.label,
    required List<Option<T>> options,
    this.filter = const FuzzyFilter(),
  }) : options = Stream<List<Option<T>>>.multi((controller) {
         controller.add(options);
         unawaited(controller.close());
       });

  /// Options the feature narrows itself: [search] answers every query the
  /// user types, starting with the empty one for the initial listing.
  ChoiceParam.searchable({
    required this.key,
    required super.label,
    required Stream<List<Option<T>>> Function(String query) search,
  }) : filter = SearchFilter<T>(search),
       options = search('');

  @override
  final ParamKey<T> key;

  /// The initial listing.
  final Stream<List<Option<T>>> options;

  final OptionFilter filter;
}

/// Multiple selection from a list of options.
final class MultiChoiceParam<T> extends Param {
  const MultiChoiceParam({
    required this.key,
    required super.label,
    required this.options,
    this.min,
    this.max,
  });

  /// Convenience for a fixed option list.
  MultiChoiceParam.fixed({
    required this.key,
    required super.label,
    required List<Option<T>> options,
    this.min,
    this.max,
  }) : options = Stream<List<Option<T>>>.multi((controller) {
         controller.add(options);
         unawaited(controller.close());
       });

  @override
  final ParamKey<List<T>> key;

  final Stream<List<Option<T>>> options;
  final int? min;
  final int? max;

  /// Builds the typed answer for the chosen [indexes] into [options],
  /// preserving option order.
  List<T> answerFor(List<Option<T>> options, Iterable<int> indexes) =>
      List.unmodifiable([
        for (final index in indexes) options[index].value,
      ]);
}
