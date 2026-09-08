import 'dart:convert';

import 'package:tool_protocol/src/models/tool_definition.dart';

/// Coerces string argument values to the types the tool's parameter schema
/// declares. XML-style tool-call formats (`<parameter=...>`) carry no type
/// information, so every extracted value arrives as a string even when the
/// schema asks for an integer or a list. Typed values (from JSON-style
/// extractors) pass through untouched, as do values whose coercion fails.
Map<String, Object?> coerceArguments(
  ToolDefinition definition,
  Map<String, Object?> arguments,
) {
  final rawProperties = definition.parameters['properties'];
  if (rawProperties is! Map) return arguments;

  final coerced = <String, Object?>{...arguments};
  for (final entry in arguments.entries) {
    final value = entry.value;
    if (value is! String) continue;
    final spec = rawProperties[entry.key];
    if (spec is! Map) continue;
    coerced[entry.key] = _coerceValue(value, spec['type']);
  }
  return coerced;
}

Object? _coerceValue(String value, Object? declaredType) {
  final types = switch (declaredType) {
    final String single => <Object?>[single],
    final List<Object?> union => union,
    _ => const <Object?>[],
  };

  for (final type in types) {
    switch (type) {
      case 'string':
        return value;
      case 'integer':
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      case 'number':
        final parsed = num.tryParse(value.trim());
        if (parsed != null) return parsed;
      case 'boolean':
        switch (value.trim()) {
          case 'true':
            return true;
          case 'false':
            return false;
        }
      case 'null':
        if (value.trim() == 'null') return null;
      case 'array':
        final decoded = _tryJsonDecode(value);
        if (decoded is List) return decoded;
      case 'object':
        final decoded = _tryJsonDecode(value);
        if (decoded is Map) return decoded;
    }
  }
  return value;
}

Object? _tryJsonDecode(String value) {
  try {
    return jsonDecode(value);
  } on FormatException {
    return null;
  }
}
