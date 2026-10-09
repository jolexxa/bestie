import 'package:file/file.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';

import 'gguf_writer.dart';

const qwen3Template =
    r"{{- '<|im_start|>assistant\n' }} "
    '{%- if enable_thinking is defined and enable_thinking is false %} '
    r"{{- '<think>\n\n</think>\n\n' }}{%- endif %}";

/// What DeepSeek's R1 distills of Qwen carry in place of ChatML.
const deepSeekTemplate =
    r"{{'<｜User｜>' + content}}{{'<｜Assistant｜><think>\n'}}";

/// Writes a small but well-formed GGUF to [path].
void writeGguf(
  FileSystem fileSystem,
  String path, {
  String? architecture = 'qwen3',
  String? name = 'Qwen3 1.7B',
  int? fileType = 15,
  int? contextLength = 40960,
  String? chatTemplate = qwen3Template,
  Map<String, TestValue> extra = const {},
  int padding = 0,
}) {
  final writer = GgufWriter();
  if (architecture != null) {
    writer.put('general.architecture', TestValue.string(architecture));
  }
  if (name != null) writer.put('general.name', TestValue.string(name));
  if (fileType != null) {
    writer.put('general.file_type', TestValue.uint32(fileType));
  }
  if (contextLength != null && architecture != null) {
    writer.put('$architecture.context_length', TestValue.uint32(contextLength));
  }
  if (chatTemplate != null) {
    writer.put('tokenizer.chat_template', TestValue.string(chatTemplate));
  }
  extra.forEach(writer.put);
  writer.tensor('token_embd.weight', [16, 4]);
  fileSystem.file(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync([...writer.build(), ...List.filled(padding, 0)]);
}

SupportedModel supportedModel({
  String id = 'qwen3-1.7b-q4_k_m-1a2b3c4d',
  String path = '/models/Qwen3-1.7B-Q4_K_M.gguf',
  String displayName = 'Qwen3 1.7B',
  ModelSource source = const ScannedSource(root: '/models'),
  ModelReasoning detectedReasoning = const ModelReasoningToggle(),
}) => SupportedModel(
  id: id,
  path: path,
  displayName: displayName,
  sizeBytes: 1000,
  fingerprint: '1a2b3c4d',
  source: source,
  profile: ModelProfileId.qwen3,
  architecture: 'qwen3',
  quant: QuantType.q4KMedium,
  contextLength: 40960,
  parameterCount: 1700,
  detectedReasoning: detectedReasoning,
  sampling: const ModelSamplingDefaults(temperature: 0.6),
);

UnsupportedModel unsupportedModel({
  String id = 'granite-4.0-h-micro-q4_k_m-0badf00d',
  String path = '/models/granite-4.0-h-micro-Q4_K_M.gguf',
  String displayName = 'Granite-4.0-H-Micro',
  ModelSource source = const ScannedSource(root: '/models'),
}) => UnsupportedModel(
  id: id,
  path: path,
  displayName: displayName,
  sizeBytes: 2000,
  fingerprint: '0badf00d',
  source: source,
  reason: const ArchitectureUnsupported('granitehybrid'),
);
