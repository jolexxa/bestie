import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

part 'git.mapper.dart';

/// Type of entry in a Git tree listing.
@MappableEnum()
enum GitEntryType {
  /// A regular file.
  file,

  /// A directory.
  directory,
}

/// An entry in a repository's file tree.
@model
@MappableClass()
@immutable
class GitTreeEntry with GitTreeEntryMappable {
  /// Creates a [GitTreeEntry].
  const GitTreeEntry({
    required this.path,
    required this.type,
    this.oid,
    this.size,
    this.lastCommit,
  });

  /// Path relative to the repository root.
  final String path;

  /// Whether this entry is a file or directory.
  final GitEntryType type;

  /// Git object identifier.
  final String? oid;

  /// Size in bytes (files only).
  final int? size;

  /// Information about the last commit that modified this entry.
  final GitLastCommitInfo? lastCommit;
}

/// Commit metadata for the last modification of a tree entry.
@model
@MappableClass()
@immutable
class GitLastCommitInfo with GitLastCommitInfoMappable {
  /// Creates a [GitLastCommitInfo].
  const GitLastCommitInfo({
    required this.id,
    required this.title,
    required this.date,
  });

  /// The commit SHA.
  final String id;

  /// The commit title (first line of the commit message).
  final String title;

  /// When the commit was made.
  final DateTime date;
}
