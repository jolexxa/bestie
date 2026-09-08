import 'package:dart_mappable/dart_mappable.dart';

part 'file_diff.mapper.dart';

/// What a line in a diff did.
@MappableEnum()
enum DiffLineKind { context, added, removed }

/// One line of a hunk, without its line ending.
@MappableClass()
final class DiffLine with DiffLineMappable {
  const DiffLine({required this.kind, required this.text});

  final DiffLineKind kind;
  final String text;
}

/// One run of changed lines with its context, addressed 1-based in both
/// versions of the file.
@MappableClass()
final class DiffHunk with DiffHunkMappable {
  const DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });

  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<DiffLine> lines;
}

/// A change to one file as unified-diff hunks. [added] and [removed] count
/// the whole change even when [truncated] dropped some of its lines.
@MappableClass()
final class FileDiff with FileDiffMappable {
  const FileDiff({
    required this.hunks,
    required this.added,
    required this.removed,
    this.truncated = false,
  });

  final List<DiffHunk> hunks;
  final int added;
  final int removed;
  final bool truncated;
}
