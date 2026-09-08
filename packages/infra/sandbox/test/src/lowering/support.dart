import 'package:file/file.dart';
import 'package:file/memory.dart';

/// An in-memory filesystem seeded with standalone [files], [dirs] (each a
/// directory mapped to the child paths beneath it), and [symlinks] (link path
/// → target). Symlink targets must exist, so declare them via [files]/[dirs].
FileSystem memFs({
  Set<String> files = const {},
  Map<String, List<String>> dirs = const {},
  Map<String, String> symlinks = const {},
}) {
  final fs = MemoryFileSystem();
  for (final path in files) {
    fs.file(path).createSync(recursive: true);
  }
  for (final entry in dirs.entries) {
    fs.directory(entry.key).createSync(recursive: true);
    for (final child in entry.value) {
      if (dirs.containsKey(child)) {
        fs.directory(child).createSync(recursive: true);
      } else {
        fs.file(child).createSync(recursive: true);
      }
    }
  }
  for (final entry in symlinks.entries) {
    fs.link(entry.key).createSync(entry.value, recursive: true);
  }
  return fs;
}
