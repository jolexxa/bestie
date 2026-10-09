import 'dart:async';
import 'dart:io' show FileSystemEvent, FileSystemMoveEvent;

import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:path/path.dart' as p;

/// The model index the app keeps and the server loads models from. Reading
/// it needs no server, so listing models never starts one.
@PartOf(LocalInferenceClient)
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

  /// Emits whenever the index is written, replaced or removed. The folder
  /// is watched rather than the file, because the index is replaced by a
  /// rename on every write.
  Stream<void> get changes => Stream<void>.multi((listener) {
    final subscription = _folderEvents()
        .where(_touchesIndex)
        .listen(
          (_) => listener.add(null),
          onError: (Object _) {},
          onDone: listener.close,
        );
    listener.onCancel = subscription.cancel;
  });

  Stream<FileSystemEvent> _folderEvents() {
    final folder = _fileSystem.file(_path).parent;
    try {
      folder.createSync(recursive: true);
    } on FileSystemException {
      return const Stream.empty();
    }
    return folder.watch();
  }

  bool _touchesIndex(FileSystemEvent event) =>
      p.basename(event.path) == p.basename(_path) ||
      (event is FileSystemMoveEvent &&
          p.basename(event.destination ?? '') == p.basename(_path));
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
