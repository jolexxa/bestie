/// The label-template placeholder grammar: `${arg}` or `${arg:modifier}`.
final labelPlaceholder = RegExp(r'\$\{([A-Za-z_]\w*)(?::([A-Za-z]+))?\}');

/// The argument names [template] substitutes, in first-use order.
///
/// Used to keep only the arguments a stamped label needs, rather than
/// duplicating a call's whole argument map.
Set<String> labelArgumentKeys(String template) => {
  for (final match in labelPlaceholder.allMatches(template)) match.group(1)!,
};

/// [arguments] reduced to the entries [template] substitutes.
Map<String, Object?> labelArgumentsFor(
  String template,
  Map<String, Object?> arguments,
) {
  final keys = labelArgumentKeys(template);
  return {
    for (final entry in arguments.entries)
      if (keys.contains(entry.key)) entry.key: entry.value,
  };
}
