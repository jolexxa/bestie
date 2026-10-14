import 'dart:convert';
import 'dart:io' show pid;

import 'package:dart_mappable/dart_mappable.dart';
import 'package:file/file.dart';
import 'package:model_index_store/src/store_result.dart';

var _writesStarted = 0;

/// Reads [path] and decodes it with [decode].
Future<StoreReadResult<Value>> readJsonFile<Value>(
  FileSystem fileSystem,
  String path,
  Value Function(String json) decode,
) async {
  final file = fileSystem.file(path);
  try {
    if (!file.existsSync()) return StoreAbsent<Value>();
    return StoreLoaded(decode(await file.readAsString()));
  } on FileSystemException catch (error) {
    return StoreUnreadable('${error.message}: $path');
  } on FormatException catch (error) {
    return StoreCorrupt('$path is not valid JSON: ${error.message}');
  } on MapperException catch (error) {
    return StoreCorrupt('$path does not match its schema: ${error.message}');
  }
}

/// Writes [json] beside [path] first, then renames it over [path], so a
/// crash never leaves a half-written file behind. Every write has its own
/// temporary file, so concurrent writers, in this process or another, never
/// share one.
Future<StoreWriteResult> writeJsonFile(
  FileSystem fileSystem,
  String path,
  Object json,
) async {
  final file = fileSystem.file(path);
  try {
    await file.parent.create(recursive: true);
    final temporary = await fileSystem
        .file('$path.$pid-${_writesStarted++}.tmp')
        .writeAsString(
          const JsonEncoder.withIndent('  ').convert(json),
          flush: true,
        );
    await temporary.rename(path);
    return const StoreWritten();
  } on FileSystemException catch (error) {
    return StoreWriteFailed('${error.message}: $path');
  }
}
