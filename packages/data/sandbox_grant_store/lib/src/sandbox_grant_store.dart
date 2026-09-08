import 'dart:convert';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:sandbox_grant_store/src/sandbox_grants.dart';

/// Reads and writes the single sandbox-grants document.
@dataSource
class SandboxGrantStore {
  SandboxGrantStore({required this.file, required this.fileSystem});

  final String file;
  final FileSystem fileSystem;

  SandboxGrants load() {
    final handle = fileSystem.file(file);
    if (!handle.existsSync()) return const SandboxGrants();
    final content = handle.readAsStringSync().trim();
    if (content.isEmpty) return const SandboxGrants();
    try {
      final decoded = jsonDecode(content) as Map<String, Object?>;
      return SandboxGrantsMapper.fromMap(decoded);
    } on FormatException {
      return const SandboxGrants();
    } on MapperException {
      return const SandboxGrants();
    }
  }

  /// Deletes the document.
  void clear() {
    final handle = fileSystem.file(file);
    if (handle.existsSync()) handle.deleteSync();
  }

  void save(SandboxGrants grants) {
    final handle = fileSystem.file(file);
    final parent = handle.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    fileSystem.file('$file.tmp')
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(grants.toMap()),
        flush: true,
      )
      ..renameSync(file);
  }
}
