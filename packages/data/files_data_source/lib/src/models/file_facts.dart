import 'package:files_data_source/src/models/file_kind.dart';
import 'package:intentions/intentions.dart';

/// What a path is, without reading what it holds.
@model
final class FileFacts {
  const FileFacts({
    required this.path,
    required this.kind,
    required this.size,
    required this.modified,
    required this.accessed,
    required this.changed,
    required this.mode,
    required this.modeDescription,
  });

  /// Absolute path, as the filesystem spells it.
  final String path;

  final FileKind kind;

  /// Size in bytes.
  final int size;

  final DateTime modified;
  final DateTime accessed;
  final DateTime changed;

  final int mode;

  /// Permission bits written the way `ls` writes them.
  final String modeDescription;
}
