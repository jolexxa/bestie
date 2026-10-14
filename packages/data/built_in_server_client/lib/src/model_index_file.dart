import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';

/// The model index the app keeps and the server loads models from. Reading
/// it needs no server, so listing models never starts one.
@PartOf(BuiltInServerClient)
final class ModelIndexFile {
  ModelIndexFile({required FileSystem fileSystem, required String path})
    : _fileSystem = fileSystem,
      _path = path;

  final FileSystem _fileSystem;
  final String _path;

  /// The entries this version can load; none before the index exists.
  Future<ModelIndexRead> read() async {
    final file = _fileSystem.file(_path);
    if (!file.existsSync()) return const ModelIndexListed([]);
    try {
      return switch (ModelIndex.decode(await file.readAsString())) {
        ModelIndexDecoded(:final index) => ModelIndexListed(index.models),
        ModelIndexUndecodable(:final message) => ModelIndexUnreadable(
          'The model index is damaged: $message',
        ),
      };
    } on FileSystemException catch (error) {
      return ModelIndexUnreadable(
        "The model index can't be read: ${error.message}",
      );
    }
  }
}

/// How reading the model index went.
@model
sealed class ModelIndexRead {
  const ModelIndexRead();
}

@model
final class ModelIndexListed extends ModelIndexRead {
  const ModelIndexListed(this.entries);

  final List<ModelIndexEntry> entries;
}

@model
final class ModelIndexUnreadable extends ModelIndexRead {
  const ModelIndexUnreadable(this.reason);

  final String reason;
}
