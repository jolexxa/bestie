import 'dart:convert';

import 'package:file/file.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

const qwenEntry = ModelIndexEntry(
  localId: 'qwen3-1.7b',
  path: '/models/qwen3.gguf',
  displayName: 'Qwen3 1.7B',
  profileId: ModelProfileId.qwen3,
  architecture: 'qwen3',
  fileType: 'Q4_K_M',
  sizeBytes: 1000,
  trainedContextLength: 40960,
  reasoning: ModelReasoningToggle(),
  defaultSampling: ModelSamplingDefaults(temperature: 0.6, topK: 20),
  provenance: ModelScanned(root: '/models'),
  fingerprint: 'abc',
);

const gemmaEntry = ModelIndexEntry(
  localId: 'gemma',
  path: '/models/gemma.gguf',
  displayName: 'Gemma',
  profileId: ModelProfileId.gemma4,
  architecture: 'gemma4',
  fileType: 'Q8_0',
  sizeBytes: 2000,
  trainedContextLength: 8192,
  reasoning: ModelReasoningNone(),
  defaultSampling: ModelSamplingDefaults(),
  provenance: ModelScanned(root: '/models'),
  fingerprint: 'def',
);

void writeIndex(
  FileSystem fileSystem,
  String path,
  List<ModelIndexEntry> entries,
) {
  fileSystem.file(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      ModelIndex(version: ModelIndex.currentVersion, models: entries).toJson(),
    );
}

const unknownProfileId = 'llama2-7b';

/// Writes [entries] after one entry naming a profile no server knows.
void writeIndexWithUnknownProfile(
  FileSystem fileSystem,
  String path,
  List<ModelIndexEntry> entries,
) {
  final unknown = qwenEntry.toMap()
    ..['local_id'] = unknownProfileId
    ..['profile_id'] = 'llama2';
  fileSystem.file(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(
      jsonEncode({
        'version': ModelIndex.currentVersion,
        'models': [unknown, for (final entry in entries) entry.toMap()],
      }),
    );
}
