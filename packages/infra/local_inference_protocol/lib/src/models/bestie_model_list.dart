import 'package:dart_mappable/dart_mappable.dart';
import 'package:local_inference_protocol/src/models/model_reasoning.dart';

part 'bestie_model_list.mapper.dart';

/// The server's `GET /v1/models` body: the OpenAI listing with bestie fields
/// on each model.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class BestieModelList with BestieModelListMappable {
  const BestieModelList({required this.data, this.object = 'list'});

  final String object;

  final List<BestieModel> data;
}

/// One indexed model, in OpenAI shape plus its context length and bestie
/// facts.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class BestieModel with BestieModelMappable {
  const BestieModel({
    required this.id,
    required this.contextLength,
    required this.bestie,
    required this.created,
    this.object = 'model',
    this.ownedBy = 'bestie',
  });

  /// The model's local id.
  final String id;

  final String object;

  final String ownedBy;

  /// Seconds since the epoch.
  final int created;

  /// The context the model was trained for. The fitted context of a loaded
  /// model is reported by its ready status instead.
  final int contextLength;

  final BestieModelFacts bestie;
}

/// What bestie knows about a served model beyond the OpenAI fields.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class BestieModelFacts with BestieModelFactsMappable {
  const BestieModelFacts({
    required this.loaded,
    required this.reasoning,
    required this.displayName,
    required this.fileType,
    required this.sizeBytes,
  });

  final bool loaded;

  final ModelReasoning reasoning;

  final String displayName;

  /// The quantization label, e.g. `Q4_K_M`.
  final String fileType;

  final int sizeBytes;
}
