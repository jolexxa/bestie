import 'dart:math' as math;

import 'package:config_protocol/src/validation.dart';

abstract interface class ConfigFieldBase {
  String get label;
  String get description;
  int get maxLines;
  bool get customEditable;

  /// Whether the value should stay hidden while browsing.
  bool get secret;

  Object? adjustValue(Object? current, int delta);
  String formatValue(Object? value);
  Object? parseValue(String text);
  Validation validateValue(Object? value);
}

sealed class ConfigField<T> implements ConfigFieldBase {
  ConfigField({required this.label, required this.description});

  @override
  final String label;
  @override
  final String description;

  T adjust(T current, int delta);

  String format(T value);

  T? parse(String text);

  Validation validate(T value);

  @override
  int get maxLines => 1;

  @override
  bool get customEditable => true;

  @override
  bool get secret => false;

  @override
  Object? adjustValue(Object? current, int delta) =>
      adjust(current as T, delta);

  @override
  String formatValue(Object? value) => value == null ? '' : format(value as T);

  @override
  Object? parseValue(String text) => parse(text);

  @override
  Validation validateValue(Object? value) =>
      value == null ? const Valid() : validate(value as T);
}

final class NumericField<T extends num> extends ConfigField<T> {
  NumericField({
    required super.label,
    required super.description,
    required this.min,
    required this.max,
    required this.step,
  });

  final T min;
  final T max;
  final T step;

  @override
  T adjust(T current, int delta) {
    final raw = current + step * delta;
    final clamped = math.min(math.max(raw, min), max);
    return clamped is int ? clamped as T : _roundToStep(clamped) as T;
  }

  @override
  String format(T value) {
    if (value is int) return value.toString();
    return (value as double).toStringAsFixed(_precision);
  }

  @override
  T? parse(String text) {
    if (T == int) {
      return int.tryParse(text) as T?;
    }
    return double.tryParse(text) as T?;
  }

  @override
  Validation validate(T value) {
    if (value < min || value > max) {
      return Invalid('Must be between ${format(min)} and ${format(max)}');
    }
    return const Valid();
  }

  @override
  bool get customEditable => true;

  int get _precision {
    final s = step.toString();
    final dot = s.indexOf('.');
    if (dot == -1) return 0;
    return s.length - dot - 1;
  }

  double _roundToStep(num value) {
    final factor = math.pow(10, _precision);
    return (value * factor).roundToDouble() / factor;
  }
}

final class BoolField extends ConfigField<bool> {
  BoolField({required super.label, required super.description});

  @override
  bool adjust(bool current, int delta) => !current;

  @override
  String format(bool value) => value ? 'true' : 'false';

  @override
  bool? parse(String text) => switch (text.toLowerCase()) {
    'true' || '1' => true,
    'false' || '0' => false,
    _ => null,
  };

  @override
  Validation validate(bool value) => const Valid();

  @override
  bool get customEditable => false;
}

final class EnumField<T> extends ConfigField<T> {
  EnumField({
    required super.label,
    required super.description,
    required this.options,
    required this.optionLabel,
  });

  final List<T> Function() options;
  final String Function(T) optionLabel;

  @override
  T adjust(T current, int delta) {
    final opts = options();
    final i = opts.indexOf(current);
    if (i == -1) return opts.first;
    final next = (i + delta) % opts.length;
    return opts[next];
  }

  @override
  String format(T value) => optionLabel(value);

  @override
  T? parse(String text) {
    final lower = text.toLowerCase();
    for (final option in options()) {
      if (optionLabel(option).toLowerCase() == lower) return option;
    }
    return null;
  }

  @override
  Validation validate(T value) {
    final opts = options();
    if (!opts.contains(value)) {
      return Invalid('Must be one of: ${opts.map(optionLabel).join(', ')}');
    }
    return const Valid();
  }

  @override
  bool get customEditable => false;
}

final class OpaqueField<T> extends ConfigField<T> {
  OpaqueField({
    required super.label,
    required super.description,
    int maxLines = 1,
    this.secret = false,
  }) : _maxLines = maxLines;

  final int _maxLines;

  @override
  final bool secret;

  @override
  int get maxLines => _maxLines;

  @override
  T adjust(T current, int delta) => current;

  @override
  String format(T value) => value?.toString() ?? '';

  @override
  T? parse(String text) => text as T;

  @override
  Validation validate(T value) => const Valid();
}
