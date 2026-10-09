import 'dart:convert';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:llm_model_profiles/llm_model_profiles.dart';
import 'package:local_inference_protocol/src/models/model_reasoning.dart';

part 'model_index.mapper.dart';

/// Every local model bestie knows about, written by the app and read by the
/// server.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class ModelIndex with ModelIndexMappable {
  const ModelIndex({required this.version, required this.models});

  static const fileName = 'index.json';

  static const currentVersion = 1;

  final int version;

  final List<ModelIndexEntry> models;

  /// Decodes [json] one entry at a time, so an entry this version cannot
  /// read, such as one naming a profile it does not know, is skipped rather
  /// than spoiling the whole index.
  static ModelIndexDecodeResult decode(String json) {
    final Object? document;
    try {
      document = jsonDecode(json);
    } on FormatException catch (error) {
      return ModelIndexUndecodable(message: error.message);
    }
    if (document case {
      'version': final int version,
      'models': final List<Object?> rawEntries,
    }) {
      final entries = rawEntries.map(_entryOf).nonNulls.toList();
      return ModelIndexDecoded(
        index: ModelIndex(version: version, models: entries),
        skippedEntries: rawEntries.length - entries.length,
      );
    }
    return const ModelIndexUndecodable(
      message: 'The index has no version and models list.',
    );
  }

  static ModelIndexEntry? _entryOf(Object? rawEntry) {
    if (rawEntry is! Map<String, Object?>) return null;
    try {
      return ModelIndexEntryMapper.fromMap(rawEntry);
    } on MapperException {
      return null;
    }
  }
}

sealed class ModelIndexDecodeResult {
  const ModelIndexDecodeResult();
}

/// The index, without the entries that could not be read.
final class ModelIndexDecoded extends ModelIndexDecodeResult {
  const ModelIndexDecoded({required this.index, required this.skippedEntries});

  final ModelIndex index;

  /// How many entries were left out because they could not be read.
  final int skippedEntries;
}

/// The file is not an index at all.
final class ModelIndexUndecodable extends ModelIndexDecodeResult {
  const ModelIndexUndecodable({required this.message});

  final String message;
}

/// One GGUF on disk and the facts read from its header.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class ModelIndexEntry with ModelIndexEntryMappable {
  const ModelIndexEntry({
    required this.localId,
    required this.path,
    required this.displayName,
    required this.profileId,
    required this.architecture,
    required this.fileType,
    required this.sizeBytes,
    required this.trainedContextLength,
    required this.reasoning,
    required this.defaultSampling,
    required this.provenance,
    required this.fingerprint,
    this.parameterCount,
  });

  /// Stable id: a slug of the model's name plus its fingerprint.
  final String localId;

  /// Absolute path to the GGUF, or to its first split.
  final String path;

  final String displayName;

  /// The prompt-format profile the server formats this model with.
  final ModelProfileId profileId;

  /// The header's `general.architecture`.
  final String architecture;

  /// The quantization label, e.g. `Q4_K_M`.
  final String fileType;

  final int sizeBytes;

  final int? parameterCount;

  final int trainedContextLength;

  final ModelReasoning reasoning;

  final ModelSamplingDefaults defaultSampling;

  final ModelProvenance provenance;

  /// Eight hex digits derived from the file size and header bytes.
  final String fingerprint;
}

/// The sampling a model's author recommends.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class ModelSamplingDefaults with ModelSamplingDefaultsMappable {
  const ModelSamplingDefaults({
    this.temperature,
    this.topK,
    this.topP,
    this.minP,
  });

  final double? temperature;

  final int? topK;

  final double? topP;

  final double? minP;
}

/// Where a local model came from.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorKey: 'source')
sealed class ModelProvenance with ModelProvenanceMappable {
  const ModelProvenance();
}

/// Downloaded by bestie from a Hugging Face repo.
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  discriminatorValue: 'downloaded',
)
final class ModelDownloaded extends ModelProvenance
    with ModelDownloadedMappable {
  const ModelDownloaded({
    required this.repo,
    required this.file,
    this.revision,
  });

  final String repo;

  final String? revision;

  final String file;
}

/// Found while scanning a models folder.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorValue: 'scanned')
final class ModelScanned extends ModelProvenance with ModelScannedMappable {
  const ModelScanned({required this.root});

  /// The scanned folder the model was found under.
  final String root;
}
