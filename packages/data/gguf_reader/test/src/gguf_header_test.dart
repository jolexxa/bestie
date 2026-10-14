import 'package:gguf_reader/gguf_reader.dart';
import 'package:test/test.dart';

GgufHeader _header(Map<String, GgufValue> metadata) => GgufHeader(
  version: 3,
  isBigEndian: false,
  metadata: metadata,
  tensors: const [],
  headerByteLength: 100,
  alignment: 32,
);

GgufValue _string(String value) => GgufString(value);
GgufValue _uint32(int value) => GgufInteger(GgufValueType.uint32, value);
GgufValue _float32(double value) => GgufFloat(GgufValueType.float32, value);

void main() {
  group('GgufHeader', () {
    test('exposes general.* facts', () {
      final header = _header({
        'general.architecture': _string('qwen3'),
        'general.name': _string('Qwen3 1.7B'),
        'general.basename': _string('Qwen3'),
        'general.finetune': _string('Instruct'),
        'general.size_label': _string('1.7B'),
        'general.file_type': _uint32(15),
        'general.quantized_by': _string('Unsloth'),
        'general.url': _string('https://example.com/model'),
        'general.repo_url': _string('https://huggingface.co/Qwen/Qwen3-1.7B'),
        'general.source.url': _string('https://example.com/source'),
        'general.source.repo_url': _string('https://github.com/qwen/qwen3'),
        'general.source.huggingface.repository': _string('Qwen/Qwen3-1.7B'),
        'tokenizer.chat_template': _string('{{ messages }}'),
      });

      expect(header.architecture, 'qwen3');
      expect(header.name, 'Qwen3 1.7B');
      expect(header.basename, 'Qwen3');
      expect(header.finetune, 'Instruct');
      expect(header.sizeLabel, '1.7B');
      expect(header.fileType, 15);
      expect(header.quantizedBy, 'Unsloth');
      expect(header.url, 'https://example.com/model');
      expect(header.repoUrl, 'https://huggingface.co/Qwen/Qwen3-1.7B');
      expect(header.sourceUrl, 'https://example.com/source');
      expect(header.sourceRepoUrl, 'https://github.com/qwen/qwen3');
      expect(header.sourceHuggingFaceRepository, 'Qwen/Qwen3-1.7B');
      expect(header.chatTemplate, '{{ messages }}');
    });

    test('reads {arch}.* hyperparameters for the declared architecture', () {
      final header = _header({
        'general.architecture': _string('gemma3'),
        'gemma3.context_length': _uint32(32768),
        'gemma3.block_count': _uint32(26),
        'gemma3.embedding_length': _uint32(1152),
        'gemma3.attention.head_count': _uint32(4),
        'gemma3.attention.head_count_kv': _uint32(1),
        'gemma3.attention.key_length': _uint32(256),
        'llama.context_length': _uint32(4096),
      });

      expect(header.contextLength, 32768);
      expect(header.blockCount, 26);
      expect(header.embeddingLength, 1152);
      expect(header.headCount, 4);
      expect(header.headCountKv, 1);
      expect(header.keyLength, 256);
    });

    test('has no hyperparameters without an architecture', () {
      final header = _header({'llama.context_length': _uint32(4096)});

      expect(header.architecture, isNull);
      expect(header.contextLength, isNull);
    });

    test('lists base models', () {
      final header = _header({
        'general.base_model.count': _uint32(2),
        'general.base_model.0.name': _string('Llama 3.2 1B'),
        'general.base_model.0.organization': _string('Meta Llama'),
        'general.base_model.0.repo_url': _string(
          'https://huggingface.co/meta-llama/Llama-3.2-1B',
        ),
        'general.base_model.1.url': _string('https://example.com/base'),
      });

      final baseModels = header.baseModels;

      expect(baseModels, hasLength(2));
      expect(baseModels.first.index, 0);
      expect(baseModels.first.name, 'Llama 3.2 1B');
      expect(baseModels.first.organization, 'Meta Llama');
      expect(
        baseModels.first.repoUrl,
        'https://huggingface.co/meta-llama/Llama-3.2-1B',
      );
      expect(baseModels.last.index, 1);
      expect(baseModels.last.name, isNull);
      expect(baseModels.last.url, 'https://example.com/base');
    });

    test('has no base models when none are declared', () {
      expect(_header(const {}).baseModels, isEmpty);
    });

    test('reads recommended sampling, widening integers to doubles', () {
      final header = _header({
        'general.sampling.temp': _float32(0.6),
        'general.sampling.top_k': const GgufInteger(GgufValueType.int32, 20),
        'general.sampling.top_p': _float32(0.95),
        'general.sampling.min_p': _uint32(0),
        'general.sampling.penalty_last_n': const GgufInteger(
          GgufValueType.int32,
          64,
        ),
        'general.sampling.penalty_repeat': _float32(1.5),
      });

      final sampling = header.sampling;

      expect(sampling.temperature, closeTo(0.6, 1e-6));
      expect(sampling.topK, 20);
      expect(sampling.topP, closeTo(0.95, 1e-6));
      expect(sampling.minP, 0.0);
      expect(sampling.penaltyLastN, 64);
      expect(sampling.penaltyRepeat, 1.5);
    });

    test('typed lookups ignore values of the wrong type', () {
      final header = _header({
        'text': _string('1'),
        'number': _uint32(1),
        'flag': const GgufBool(value: true),
      });

      expect(header.intValue('text'), isNull);
      expect(header.stringValue('number'), isNull);
      expect(header.doubleValue('flag'), isNull);
      expect(header.intValue('absent'), isNull);
    });

    test('sums tensor element counts and aligns the data offset', () {
      const header = GgufHeader(
        version: 3,
        isBigEndian: false,
        metadata: {},
        tensors: [
          GgufTensorInfo(
            name: 'a',
            dimensions: [3, 4],
            ggmlType: 0,
            offset: 0,
          ),
          GgufTensorInfo(name: 'b', dimensions: [5], ggmlType: 1, offset: 64),
        ],
        headerByteLength: 65,
        alignment: 32,
      );

      expect(header.parameterCount, 17);
      expect(header.tensorDataOffset, 96);
    });
  });
}
