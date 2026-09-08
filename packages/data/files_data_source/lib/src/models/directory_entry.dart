import 'package:files_data_source/src/models/file_kind.dart';
import 'package:intentions/intentions.dart';

/// One child of a listed directory.
@model
final class DirectoryEntry {
  const DirectoryEntry({
    required this.name,
    required this.path,
    required this.kind,
    required this.size,
  });

  /// Final path segment.
  final String name;

  /// Absolute path, as the filesystem spells it.
  final String path;

  final FileKind kind;

  /// Size in bytes, zero for anything that is not a file.
  final int size;
}
