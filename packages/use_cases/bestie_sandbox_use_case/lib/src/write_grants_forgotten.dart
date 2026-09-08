import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// The user took back every directory they had granted the agent's programs
/// write access to.
@model
@immutable
final class WriteGrantsForgotten {
  const WriteGrantsForgotten({required this.directories});

  /// The directories taken back, possibly none.
  final List<String> directories;

  @override
  bool operator ==(Object other) =>
      other is WriteGrantsForgotten &&
      other.directories.length == directories.length &&
      other.directories.indexed.every(
        (entry) => directories[entry.$1] == entry.$2,
      );

  @override
  int get hashCode => Object.hashAll(directories);
}
