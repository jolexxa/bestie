import 'package:file/file.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// Reads the model index the app writes.
final class ModelIndexReader {
  const ModelIndexReader({required FileSystem fileSystem, required this.path})
    : _fileSystem = fileSystem;

  final FileSystem _fileSystem;

  final String path;

  Future<ModelIndexReadResult> read() async {
    final file = _fileSystem.file(path);
    if (!file.existsSync()) return const ModelIndexMissing();
    final String json;
    try {
      json = await file.readAsString();
    } on FileSystemException catch (error) {
      return ModelIndexMalformed(message: error.message);
    }
    return switch (ModelIndex.decode(json)) {
      ModelIndexDecoded(:final index, :final skippedEntries) => ModelIndexRead(
        index,
        skippedEntries: skippedEntries,
      ),
      ModelIndexUndecodable(:final message) => ModelIndexMalformed(
        message: message,
      ),
    };
  }
}

sealed class ModelIndexReadResult {
  const ModelIndexReadResult();
}

/// The index's loadable entries.
final class ModelIndexRead extends ModelIndexReadResult {
  const ModelIndexRead(this.index, {required this.skippedEntries});

  final ModelIndex index;

  /// Entries left out because this server cannot load them.
  final int skippedEntries;

  ModelIndexEntry? entryFor(String localId) =>
      index.models.where((entry) => entry.localId == localId).firstOrNull;
}

/// No index has been written yet, so no models are installed.
final class ModelIndexMissing extends ModelIndexReadResult {
  const ModelIndexMissing();
}

final class ModelIndexMalformed extends ModelIndexReadResult {
  const ModelIndexMalformed({required this.message});

  final String message;
}
