import 'dart:convert';
import 'dart:isolate';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:gguf_reader/gguf_reader.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/src/local_models_repository.dart';
import 'package:local_models_repository/src/models/local_model.dart';
import 'package:local_models_repository/src/models/model_source.dart';
import 'package:local_models_repository/src/models/quant_type.dart';
import 'package:local_models_repository/src/models/unsupported_reason.dart';
import 'package:local_models_repository/src/support/gguf_file_name.dart';
import 'package:local_models_repository/src/support/inferred_repo.dart';
import 'package:local_models_repository/src/support/local_id.dart';
import 'package:local_models_repository/src/support/model_family.dart';
import 'package:local_models_repository/src/support/model_task.dart';
import 'package:local_models_repository/src/support/reasoning.dart';
import 'package:path/path.dart' as p;

/// Finds every GGUF model under a set of folders and reads what each one is,
/// on a background isolate so header reads never stall the UI.
///
/// Each split model is listed once, by its first file, with every file's
/// size counted. Vision projectors, adapters and LoRAs are skipped, as are
/// hidden entries and `node_modules`. A file that is found under two folders
/// is listed under the first. A file whose size and modification time have
/// not changed since the last scan is not read again.
@PartOf(LocalModelsRepository)
class ModelScanner {
  ModelScanner({FileSystem fileSystem = const LocalFileSystem()})
    : _fileSystem = fileSystem,
      _reader = GgufReader(fileSystem: fileSystem);

  static const _skippedFolders = {'node_modules'};

  final FileSystem _fileSystem;
  final GgufReader _reader;
  Map<String, _Described> _described = const {};

  Future<List<LocalModel>> scan(List<String> roots) async {
    final previous = _described;
    final scan = await Isolate.run(() => _scan(roots, previous));
    _described = scan.described;
    return scan.models;
  }

  _Scan _scan(List<String> roots, Map<String, _Described> previous) {
    final described = <String, _Described>{};
    for (final root in roots) {
      for (final path in _modelsUnder(root)) {
        if (described.containsKey(path)) continue;
        described[path] = _describe(root, GgufFileName(path), previous[path]);
      }
    }
    return _Scan(described);
  }

  /// Linked files are followed; linked folders are not, so a link cycle
  /// cannot trap the walk. A folder that cannot be listed is skipped.
  Iterable<String> _modelsUnder(String folder) sync* {
    final List<FileSystemEntity> entries;
    try {
      entries = _fileSystem.directory(folder).listSync(followLinks: false)
        ..sort((first, second) => first.path.compareTo(second.path));
    } on FileSystemException {
      return;
    }
    for (final entry in entries) {
      final name = p.basename(entry.path);
      yield* switch (entry) {
        _ when name.startsWith('.') => const <String>[],
        Directory() when _skippedFolders.contains(name) => const <String>[],
        Directory() => _modelsUnder(entry.path),
        _ when _isFirstModelFile(entry.path) => [p.normalize(entry.path)],
        _ => const <String>[],
      };
    }
  }

  bool _isFirstModelFile(String path) {
    final name = GgufFileName(path);
    return name.isModel && name.isFirstShard && _fileSystem.isFileSync(path);
  }

  /// What [name] is, from [previous] when the file is unchanged since.
  _Described _describe(String root, GgufFileName name, _Described? previous) {
    final source = ScannedSource(
      root: root,
      inferredRepo: inferRepo(root, name.path),
    );
    final shards = [
      for (final shard in name.shardPaths)
        if (_fileSystem.file(shard).existsSync()) _fileSystem.file(shard),
    ];
    final file = _ScannedFile(
      name: name,
      sizeBytes: shards.fold(0, (sum, file) => sum + file.lengthSync()),
      shardsFound: shards.length,
      source: source,
    );
    try {
      final stamp = _Stamp(
        sizeBytes: file.sizeBytes,
        modified: _fileSystem.file(name.path).lastModifiedSync(),
      );
      return switch (previous) {
        final previous? when stamp.sameAs(previous.stamp) => previous.from(
          source,
        ),
        _ => _read(stamp, file),
      };
    } on FileSystemException catch (error) {
      return _Described.unstamped(file.unreadable(error.message));
    }
  }

  /// A file that could not be opened is read again next time, since it may
  /// open then.
  _Described _read(_Stamp stamp, _ScannedFile file) =>
      switch (_reader.read(file.name.path)) {
        GgufRead(:final header) when _isModel(header) => _Described(
          stamp,
          _fromHeader(file, header),
        ),
        GgufRead() => _Described(stamp, null),
        GgufMalformed(:final reason) => _Described(
          stamp,
          file.unreadable(reason),
        ),
        GgufUnreadable(:final reason) => _Described.unstamped(
          file.unreadable(reason),
        ),
      };

  /// Adapters and LoRAs name another `general.type`.
  static bool _isModel(GgufHeader header) =>
      (header.stringValue('general.type') ?? 'model') == 'model';

  LocalModel _fromHeader(_ScannedFile file, GgufHeader header) {
    final quant = QuantType.fromFileType(header.fileType);
    final fingerprint = fingerprintOf(
      sizeBytes: file.sizeBytes,
      identity: _headerBytes(file.name.path, header.headerByteLength),
    );
    final displayName = header.name ?? file.name.stem;
    final id = localIdOf(
      name: displayName,
      quantLabel: quant?.label ?? file.name.quantLabel,
      fingerprint: fingerprint,
    );
    UnsupportedModel unsupported(UnsupportedReason reason) => UnsupportedModel(
      id: id,
      path: file.name.path,
      displayName: displayName,
      sizeBytes: file.sizeBytes,
      fingerprint: fingerprint,
      source: file.source,
      reason: reason,
    );

    if (file.shardsFound < file.name.shardCount) {
      return unsupported(
        ShardsMissing(found: file.shardsFound, expected: file.name.shardCount),
      );
    }
    final architecture = header.architecture;
    if (architecture == null) {
      return unsupported(const MetadataMissing('general.architecture'));
    }
    final pooling = header.intValue('$architecture.pooling_type');
    if (notAChatModelPooling(pooling) case final notChat?) {
      return unsupported(notChat);
    }
    final ModelProfileId profile;
    switch (profileFor(architecture, header.chatTemplate)) {
      case ProfileUnmatched(:final reason):
        return unsupported(reason);
      case ProfileMatched(profile: final matched):
        profile = matched;
    }
    final fileType = header.fileType;
    if (fileType == null) {
      return unsupported(const MetadataMissing('general.file_type'));
    }
    if (quant == null) {
      return unsupported(QuantUnsupported(fileType));
    }
    final contextLength = header.contextLength;
    if (contextLength == null) {
      return unsupported(MetadataMissing('$architecture.context_length'));
    }
    final sampling = header.sampling;
    return SupportedModel(
      id: id,
      path: file.name.path,
      displayName: displayName,
      sizeBytes: file.sizeBytes,
      fingerprint: fingerprint,
      source: file.source,
      profile: profile,
      architecture: architecture,
      quant: quant,
      contextLength: contextLength,
      parameterCount:
          header.intValue('general.parameter_count') ??
          _parameterCount(file.name, header),
      detectedReasoning: detectReasoning(profile, header.chatTemplate),
      sampling: ModelSamplingDefaults(
        temperature: sampling.temperature,
        topK: sampling.topK,
        topP: sampling.topP,
        minP: sampling.minP,
      ),
    );
  }

  /// Every shard's tensors summed, or null when a later shard's header
  /// cannot be read.
  int? _parameterCount(GgufFileName name, GgufHeader first) {
    var total = first.parameterCount;
    for (final shard in name.shardPaths.skip(1)) {
      switch (_reader.read(shard)) {
        case GgufRead(:final header):
          total += header.parameterCount;
        case GgufMalformed() || GgufUnreadable():
          return null;
      }
    }
    return total;
  }

  List<int> _headerBytes(String path, int length) {
    final file = _fileSystem.file(path).openSync();
    try {
      return file.readSync(length);
    } finally {
      file.closeSync();
    }
  }
}

/// One walk's findings, by the path of each model's first file.
final class _Scan {
  const _Scan(this.described);

  final Map<String, _Described> described;

  List<LocalModel> get models => [
    for (final found in described.values) ?found.model,
  ];
}

/// Enough to tell whether a file changed since it was last read.
final class _Stamp {
  const _Stamp({required this.sizeBytes, required this.modified});

  final int sizeBytes;
  final DateTime modified;

  bool sameAs(_Stamp? other) =>
      other?.sizeBytes == sizeBytes && other?.modified == modified;
}

/// What a file was found to be, or null for a file that is not a model.
final class _Described {
  const _Described(this.stamp, this.model);

  /// Read without a stamp, so the next scan reads it again.
  const _Described.unstamped(this.model) : stamp = null;

  final _Stamp? stamp;
  final LocalModel? model;

  _Described from(ScannedSource source) =>
      _Described(stamp, model?.withSource(source));
}

/// What the walk learned about a file before its header was read.
final class _ScannedFile {
  const _ScannedFile({
    required this.name,
    required this.sizeBytes,
    required this.shardsFound,
    required this.source,
  });

  final GgufFileName name;
  final int sizeBytes;
  final int shardsFound;
  final ScannedSource source;

  UnsupportedModel unreadable(String reason) {
    final fingerprint = fingerprintOf(
      sizeBytes: sizeBytes,
      identity: utf8.encode(name.path),
    );
    return UnsupportedModel(
      id: localIdOf(
        name: name.stem,
        quantLabel: name.quantLabel,
        fingerprint: fingerprint,
      ),
      path: name.path,
      displayName: name.stem,
      sizeBytes: sizeBytes,
      fingerprint: fingerprint,
      source: source,
      reason: HeaderUnreadable(reason),
    );
  }
}
