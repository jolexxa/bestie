import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

/// Where the paths a model names actually lead: relative to the working
/// directory, and through any symlink to the file it reaches.
@repository
class WorkspacePaths {
  const WorkspacePaths({required FilesDataSource files}) : _files = files;

  final FilesDataSource _files;

  /// The file a tool naming [path] reads or writes, spelled the same however
  /// [path] reached it.
  String targetOf(String path) => _files.realPathOf(path);
}
