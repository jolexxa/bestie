import 'package:gguf_reader/src/gguf_base_model.dart';
import 'package:gguf_reader/src/gguf_sampling.dart';
import 'package:gguf_reader/src/gguf_split.dart';
import 'package:gguf_reader/src/gguf_tensor_info.dart';
import 'package:gguf_reader/src/gguf_value.dart';
import 'package:intentions/intentions.dart';

/// Everything a GGUF file says about itself before its tensor data.
@model
final class GgufHeader {
  const GgufHeader({
    required this.version,
    required this.isBigEndian,
    required this.metadata,
    required this.tensors,
    required this.headerByteLength,
    required this.alignment,
  });

  final int version;

  final bool isBigEndian;

  /// Every key-value pair in file order.
  final Map<String, GgufValue> metadata;

  final List<GgufTensorInfo> tensors;

  /// Bytes from the start of the file to the end of the last tensor info.
  final int headerByteLength;

  final int alignment;

  /// Where the tensor data section starts.
  int get tensorDataOffset =>
      (headerByteLength + alignment - 1) ~/ alignment * alignment;

  /// The total element count across every tensor in this file only. A split
  /// model's parameters are the sum of this over every shard named by
  /// [split].
  int get parameterCount =>
      tensors.fold(0, (sum, tensor) => sum + tensor.elementCount);

  String? stringValue(String key) => switch (metadata[key]) {
    GgufString(:final value) => value,
    _ => null,
  };

  int? intValue(String key) => switch (metadata[key]) {
    GgufInteger(:final value) => value,
    _ => null,
  };

  /// Reads floats, and integers widened to doubles.
  double? doubleValue(String key) => switch (metadata[key]) {
    GgufFloat(:final value) => value,
    GgufInteger(:final value) => value.toDouble(),
    _ => null,
  };

  String? get architecture => stringValue('general.architecture');
  String? get name => stringValue('general.name');
  String? get basename => stringValue('general.basename');
  String? get finetune => stringValue('general.finetune');
  String? get sizeLabel => stringValue('general.size_label');
  int? get fileType => intValue('general.file_type');
  String? get quantizedBy => stringValue('general.quantized_by');
  String? get url => stringValue('general.url');
  String? get repoUrl => stringValue('general.repo_url');
  String? get sourceUrl => stringValue('general.source.url');
  String? get sourceRepoUrl => stringValue('general.source.repo_url');
  String? get sourceHuggingFaceRepository =>
      stringValue('general.source.huggingface.repository');
  String? get chatTemplate => stringValue('tokenizer.chat_template');

  /// One-based count of files in a split model, or null when not split.
  int? get splitCount => intValue('split.count');

  /// Zero-based position of this file within a split model.
  int? get splitIndex => intValue('split.no');

  int? get splitTensorCount => intValue('split.tensors.count');

  /// Where this file sits in a split model, or null when it is not split.
  GgufSplit? get split {
    final index = splitIndex;
    final count = splitCount;
    if (index == null || count == null) return null;
    return GgufSplit(index: index, count: count, tensorCount: splitTensorCount);
  }

  List<GgufBaseModel> get baseModels => [
    for (
      var index = 0;
      index < (intValue('general.base_model.count') ?? 0);
      index++
    )
      GgufBaseModel(
        index: index,
        name: stringValue('general.base_model.$index.name'),
        organization: stringValue('general.base_model.$index.organization'),
        url: stringValue('general.base_model.$index.url'),
        repoUrl: stringValue('general.base_model.$index.repo_url'),
      ),
  ];

  GgufSampling get sampling => GgufSampling(
    temperature: doubleValue('general.sampling.temp'),
    topK: intValue('general.sampling.top_k'),
    topP: doubleValue('general.sampling.top_p'),
    minP: doubleValue('general.sampling.min_p'),
    penaltyLastN: intValue('general.sampling.penalty_last_n'),
    penaltyRepeat: doubleValue('general.sampling.penalty_repeat'),
  );

  int? get contextLength => _architectureInt('context_length');
  int? get blockCount => _architectureInt('block_count');
  int? get embeddingLength => _architectureInt('embedding_length');
  int? get headCount => _architectureInt('attention.head_count');
  int? get headCountKv => _architectureInt('attention.head_count_kv');
  int? get keyLength => _architectureInt('attention.key_length');

  int? _architectureInt(String suffix) => switch (architecture) {
    null => null,
    final architecture => intValue('$architecture.$suffix'),
  };
}
