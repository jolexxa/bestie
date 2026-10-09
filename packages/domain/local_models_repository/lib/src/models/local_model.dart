import 'package:intentions/intentions.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/src/models/model_source.dart';
import 'package:local_models_repository/src/models/quant_type.dart';
import 'package:local_models_repository/src/models/unsupported_reason.dart';

/// A GGUF on disk: a whole model, or the first file of a split one.
@model
sealed class LocalModel {
  const LocalModel({
    required this.id,
    required this.path,
    required this.displayName,
    required this.sizeBytes,
    required this.fingerprint,
    required this.source,
  });

  /// A slug of the model's name plus [fingerprint]; the same file keeps it
  /// across scans and restarts.
  final String id;

  /// Absolute path to the GGUF, or to a split model's first file.
  final String path;

  final String displayName;

  /// Every file of a split model together.
  final int sizeBytes;

  /// Eight hex digits from the file size and header bytes.
  final String fingerprint;

  final ModelSource source;

  LocalModel withSource(ModelSource source);

  /// This model with a user's reasoning choice applied, or the detected one
  /// restored when [override] is null.
  LocalModel withReasoningOverride(ModelReasoning? override);

  /// The model index entry the inference server loads it from, or null when
  /// the model cannot run.
  ModelIndexEntry? get indexEntry;
}

/// A model bestie can run.
@model
final class SupportedModel extends LocalModel {
  const SupportedModel({
    required super.id,
    required super.path,
    required super.displayName,
    required super.sizeBytes,
    required super.fingerprint,
    required super.source,
    required this.profile,
    required this.architecture,
    required this.quant,
    required this.contextLength,
    required this.detectedReasoning,
    required this.sampling,
    this.parameterCount,
    ModelReasoning? reasoning,
  }) : reasoning = reasoning ?? detectedReasoning;

  /// The prompt format the server uses for it.
  final ModelProfileId profile;

  final String architecture;

  final QuantType quant;

  /// The context the model was trained for.
  final int contextLength;

  final int? parameterCount;

  /// What the profile and chat template say the model can do.
  final ModelReasoning detectedReasoning;

  /// [detectedReasoning], unless the user chose otherwise.
  final ModelReasoning reasoning;

  /// The sampling the model's author recommends.
  final ModelSamplingDefaults sampling;

  @override
  SupportedModel withSource(ModelSource source) => _copy(source: source);

  @override
  SupportedModel withReasoningOverride(ModelReasoning? override) =>
      _copy(reasoning: override ?? detectedReasoning);

  SupportedModel _copy({ModelSource? source, ModelReasoning? reasoning}) =>
      SupportedModel(
        id: id,
        path: path,
        displayName: displayName,
        sizeBytes: sizeBytes,
        fingerprint: fingerprint,
        source: source ?? this.source,
        profile: profile,
        architecture: architecture,
        quant: quant,
        contextLength: contextLength,
        detectedReasoning: detectedReasoning,
        reasoning: reasoning ?? this.reasoning,
        sampling: sampling,
        parameterCount: parameterCount,
      );

  @override
  ModelIndexEntry get indexEntry => ModelIndexEntry(
    localId: id,
    path: path,
    displayName: displayName,
    profileId: profile,
    architecture: architecture,
    fileType: quant.label,
    sizeBytes: sizeBytes,
    parameterCount: parameterCount,
    trainedContextLength: contextLength,
    reasoning: reasoning,
    defaultSampling: sampling,
    provenance: source.provenance,
    fingerprint: fingerprint,
  );
}

/// A GGUF bestie cannot run, kept in the library so the user sees why.
@model
final class UnsupportedModel extends LocalModel {
  const UnsupportedModel({
    required super.id,
    required super.path,
    required super.displayName,
    required super.sizeBytes,
    required super.fingerprint,
    required super.source,
    required this.reason,
  });

  final UnsupportedReason reason;

  @override
  UnsupportedModel withSource(ModelSource source) => UnsupportedModel(
    id: id,
    path: path,
    displayName: displayName,
    sizeBytes: sizeBytes,
    fingerprint: fingerprint,
    source: source,
    reason: reason,
  );

  @override
  UnsupportedModel withReasoningOverride(ModelReasoning? override) => this;

  @override
  ModelIndexEntry? get indexEntry => null;
}
