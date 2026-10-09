import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// Identifies a Hugging Face repository by namespace and name.
@model
@immutable
class RepoId {
  const RepoId._({required this.namespace, required this.name});

  /// Two segments of letters, digits, `_`, `-` and `.`, neither starting nor
  /// ending with `-` or `.`, and never holding `--` or `..`.
  static const _segment = '[A-Za-z0-9_](?:[A-Za-z0-9_.-]*[A-Za-z0-9_])?';
  static final _pattern = RegExp(
    r'^(?!.*(?:\.\.|--))'
    '($_segment)/($_segment)'
    r'$',
  );

  /// Parses `"namespace/name"`, or returns null when [raw] is not a valid
  /// Hub repository id.
  static RepoId? tryParse(String raw) => switch (_pattern.firstMatch(raw)) {
    null => null,
    final match => RepoId._(namespace: match.group(1)!, name: match.group(2)!),
  };

  final String namespace;

  final String name;

  String get fullName => '$namespace/$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoId && namespace == other.namespace && name == other.name;

  @override
  int get hashCode => Object.hash(namespace, name);

  @override
  String toString() => fullName;
}
