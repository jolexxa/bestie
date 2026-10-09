import 'dart:convert';

import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_models_repository/src/support/gguf_file_name.dart';
import 'package:local_models_repository/src/support/inferred_repo.dart';
import 'package:local_models_repository/src/support/local_id.dart';
import 'package:local_models_repository/src/support/model_family.dart';
import 'package:local_models_repository/src/support/model_task.dart';
import 'package:local_models_repository/src/support/reasoning.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

const _chatMl = '<|im_start|>';
const _qwen35Template =
    '$_chatMl{%- if enable_thinking %}<|vision_start|><function=example> '
    '{% endif %}';
const _coderTemplate = '$_chatMl<tool_call>\n<function=name>\n<parameter=x>';
const _gptOssTemplate =
    '<|start|>system<|message|>Reasoning: {{ reasoning_effort }}<|end|> '
    '<|channel|>';
const _gemma4Template = '<|turn>user\n{{ content }}<turn|>';
const _glm4Template = '[gMASK]<sop><|user|>{{ content }}<|assistant|>';
const _glm45Template =
    "$_glm4Template{{- '</think>' if not enable_thinking else '' }}";
const _glmZ1Template = r"[gMASK]<sop>{{- '<|assistant|>\n<think>' }}";
const _forcedThinkTemplate = r"{{- '<|im_start|>assistant\n<think>\n' }}";

Matcher _notAChat(String task) =>
    isA<NotAChatModel>().having((reason) => reason.task, 'task', task);

void main() {
  group('notAChatModel', () {
    test('passes tasks that answer in text', () {
      for (final task in [
        'text-generation',
        'text2text-generation',
        'conversational',
        'image-text-to-text',
        'video-text-to-text',
        'audio-text-to-text',
        'any-to-any',
        'visual-question-answering',
        'translation',
        'summarization',
      ]) {
        expect(
          notAChatModel(task, repo: 'org/Embedding-GGUF'),
          isNull,
          reason: task,
        );
      }
    });

    test('passes an untagged repo whose name says nothing', () {
      for (final repo in [
        'Qwen/Qwen3-8B-GGUF',
        'someone/Embedded-Coder-GGUF',
        'embedding-lab/Qwen3-8B-GGUF',
      ]) {
        expect(notAChatModel(null, repo: repo), isNull, reason: repo);
      }
    });

    test('judges an untagged repo by the words of its name', () {
      for (final repo in [
        'Qwen/Qwen3-Embedding-0.6B-GGUF',
        'ggml-org/embeddinggemma-300M-GGUF',
        'someone/bge-embeddings_v2-GGUF',
        'someone/nomic.embed.text-GGUF',
      ]) {
        expect(
          notAChatModel(null, repo: repo),
          _notAChat('feature-extraction'),
          reason: repo,
        );
      }
      for (final repo in [
        'mradermacher/Qwen3-VL-Reranker-2B-GGUF',
        'someone/jina-rerank-GGUF',
      ]) {
        expect(
          notAChatModel(null, repo: repo),
          _notAChat('text-ranking'),
          reason: repo,
        );
      }
    });

    test('rejects every other task, naming it', () {
      for (final task in [
        'feature-extraction',
        'sentence-similarity',
        'text-ranking',
        'text-classification',
        'automatic-speech-recognition',
        'text-to-speech',
        'text-to-image',
      ]) {
        expect(
          notAChatModel(task, repo: 'Qwen/Qwen3-8B-GGUF'),
          _notAChat(task),
        );
      }
    });
  });

  group('notAChatModelPooling', () {
    test('passes a model that does not pool', () {
      for (final pooling in [null, 0, -1]) {
        expect(notAChatModelPooling(pooling), isNull, reason: '$pooling');
      }
    });

    test('takes a model that pools to embeddings for an embedder', () {
      for (final pooling in [1, 2, 3]) {
        expect(
          notAChatModelPooling(pooling),
          _notAChat('feature-extraction'),
          reason: '$pooling',
        );
      }
    });

    test('takes a model that pools to a rank for a reranker', () {
      expect(notAChatModelPooling(4), _notAChat('text-ranking'));
    });
  });

  group('profileFor', () {
    ModelProfileId? profileOf(String architecture, String? template) =>
        switch (profileFor(architecture, template)) {
          ProfileMatched(:final profile) => profile,
          ProfileUnmatched() => null,
        };

    ProfileUnavailable reasonFor(String architecture, String? template) =>
        (profileFor(architecture, template) as ProfileUnmatched).reason;

    test('maps unambiguous architectures, whatever their separators', () {
      expect(profileOf('qwen2', _chatMl), ModelProfileId.qwen25);
      expect(profileOf('qwen35', _chatMl), ModelProfileId.qwen35);
      expect(profileOf('qwen35moe', _chatMl), ModelProfileId.qwen35);
      expect(profileOf('gpt-oss', _gptOssTemplate), ModelProfileId.gptOss);
      expect(profileOf('gpt_oss', _gptOssTemplate), ModelProfileId.gptOss);
      expect(profileOf('gemma4', _gemma4Template), ModelProfileId.gemma4);
      expect(profileOf('glm4', _glm4Template), ModelProfileId.glm4);
      expect(profileOf('GLM4_MOE', _glm4Template), ModelProfileId.glm4);
    });

    test('tells the Qwen 3 family apart by template', () {
      expect(profileOf('qwen3', qwen3Template), ModelProfileId.qwen3);
      expect(profileOf('qwen3moe', _coderTemplate), ModelProfileId.qwen3Coder);
      expect(profileOf('qwen3', _qwen35Template), ModelProfileId.qwen35);
      expect(profileOf('qwen3next', _chatMl), ModelProfileId.qwen3);
    });

    test('prefers thinking when a template has XML tools too', () {
      expect(
        profileOf('qwen3', '$_coderTemplate {{ enable_thinking }}'),
        ModelProfileId.qwen3,
      );
    });

    test('rejects architectures no profile runs', () {
      for (final architecture in ['llama', 'glm-dsa', 'phi3', 'granite']) {
        expect(
          reasonFor(architecture, _chatMl),
          isA<ArchitectureUnsupported>().having(
            (reason) => reason.architecture,
            'architecture',
            architecture,
          ),
        );
      }
    });

    test('rejects a template from another family, or none at all', () {
      final unrecognized = isA<TemplateUnrecognized>();
      expect(reasonFor('qwen2', deepSeekTemplate), unrecognized);
      expect(reasonFor('qwen3', deepSeekTemplate), unrecognized);
      expect(reasonFor('qwen3', null), unrecognized);
      expect(reasonFor('qwen2', '$_chatMl<|im_sep|>'), unrecognized);
      expect(reasonFor('gpt-oss', _chatMl), unrecognized);
      expect(reasonFor('gemma4', _chatMl), unrecognized);
      expect(reasonFor('glm4', _chatMl), unrecognized);
    });
  });

  group('detectReasoning', () {
    test('never gives reasoning to a profile without it', () {
      expect(
        detectReasoning(ModelProfileId.qwen25, _forcedThinkTemplate),
        const ModelReasoningNone(),
      );
      expect(
        detectReasoning(ModelProfileId.qwen3Coder, qwen3Template),
        const ModelReasoningNone(),
      );
    });

    test("keeps the profile's default without a template signal", () {
      expect(
        detectReasoning(ModelProfileId.gptOss, null),
        const ModelReasoningEfforts(efforts: ['low', 'medium', 'high']),
      );
      for (final profile in [
        ModelProfileId.qwen3,
        ModelProfileId.qwen35,
        ModelProfileId.gemma4,
      ]) {
        expect(
          detectReasoning(profile, _chatMl),
          const ModelReasoningToggle(),
        );
      }
    });

    test('reads a toggle, forced thinking or effort levels', () {
      expect(
        detectReasoning(ModelProfileId.qwen3, qwen3Template),
        const ModelReasoningToggle(),
      );
      expect(
        detectReasoning(ModelProfileId.qwen3, _forcedThinkTemplate),
        const ModelReasoningAlways(),
      );
      expect(
        detectReasoning(ModelProfileId.gptOss, _gptOssTemplate),
        const ModelReasoningEfforts(efforts: ['low', 'medium', 'high']),
      );
    });

    test('reads GLM-4 thinking from its template alone', () {
      expect(
        detectReasoning(ModelProfileId.glm4, _glm4Template),
        const ModelReasoningNone(),
      );
      expect(
        detectReasoning(ModelProfileId.glm4, _glm45Template),
        const ModelReasoningToggle(),
      );
      expect(
        detectReasoning(ModelProfileId.glm4, _glmZ1Template),
        const ModelReasoningAlways(),
      );
    });

    test('lets a toggle win over a think tag it guards', () {
      expect(
        detectReasoning(
          ModelProfileId.qwen3,
          '$_forcedThinkTemplate {{ enable_thinking }}',
        ),
        const ModelReasoningToggle(),
      );
    });
  });

  group('GgufFileName', () {
    test('reads a plain model file', () {
      final name = GgufFileName('/m/Qwen3-1.7B-Q4_K_M.gguf');

      expect(name.baseName, 'Qwen3-1.7B-Q4_K_M.gguf');
      expect(name.stem, 'Qwen3-1.7B-Q4_K_M');
      expect(name.isModel, isTrue);
      expect(name.isFirstShard, isTrue);
      expect(name.shardIndex, 1);
      expect(name.shardCount, 1);
      expect(name.quantLabel, 'Q4_K_M');
      expect(name.shardPaths, ['/m/Qwen3-1.7B-Q4_K_M.gguf']);
    });

    test('lists every file of a split model', () {
      final name = GgufFileName('/m/big-Q8_0-00002-of-00003.gguf');

      expect(name.stem, 'big-Q8_0');
      expect(name.shardIndex, 2);
      expect(name.shardCount, 3);
      expect(name.isFirstShard, isFalse);
      expect(name.quantLabel, 'Q8_0');
      expect(name.shardPaths, [
        '/m/big-Q8_0-00001-of-00003.gguf',
        '/m/big-Q8_0-00002-of-00003.gguf',
        '/m/big-Q8_0-00003-of-00003.gguf',
      ]);
    });

    test('understands the dotted split style', () {
      final name = GgufFileName('phi-4-Q4_K_M.gguf-00001-of-00002.gguf');

      expect(name.stem, 'phi-4-Q4_K_M');
      expect(name.shardPaths.last, 'phi-4-Q4_K_M.gguf-00002-of-00002.gguf');
    });

    test('reads quants in any case and of every family', () {
      expect(GgufFileName('llama-f16.gguf').quantLabel, 'F16');
      expect(GgufFileName('a-bf16.gguf').quantLabel, 'BF16');
      expect(GgufFileName('a.IQ2_XXS.gguf').quantLabel, 'IQ2_XXS');
      expect(GgufFileName('gpt-oss-20b-MXFP4.gguf').quantLabel, 'MXFP4');
      expect(GgufFileName('bitnet-TQ1_0.gguf').quantLabel, 'TQ1_0');
      expect(GgufFileName('q-UD-Q4_K_XL.gguf').quantLabel, 'Q4_K_XL');
      expect(GgufFileName('Qwen3-1.7B.gguf').quantLabel, isNull);
    });

    test('is not a model when it is a projector or another file', () {
      expect(GgufFileName('mmproj-model-f16.gguf').isModel, isFalse);
      expect(GgufFileName('README.md').isModel, isFalse);
      expect(GgufFileName('model.gguf.part').isModel, isFalse);
      expect(GgufFileName('MODEL.GGUF').isModel, isTrue);
    });
  });

  group('local ids', () {
    test('slugs names into lowercase words', () {
      expect(slugOf('Qwen3 1.7B'), 'qwen3-1.7b');
      expect(slugOf('  --Hello, World!--  '), 'hello-world');
      expect(slugOf('Q4_K_M'), 'q4_k_m');
    });

    test('fingerprints size and identity into eight hex digits', () {
      final fingerprint = fingerprintOf(
        sizeBytes: 10,
        identity: utf8.encode('header'),
      );

      expect(fingerprint, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(
        fingerprintOf(sizeBytes: 10, identity: utf8.encode('header')),
        fingerprint,
      );
      expect(
        fingerprintOf(sizeBytes: 11, identity: utf8.encode('header')),
        isNot(fingerprint),
      );
      expect(
        fingerprintOf(sizeBytes: 10, identity: utf8.encode('other')),
        isNot(fingerprint),
      );
    });

    test('adds the quant only when the name lacks it', () {
      expect(
        localIdOf(name: 'Qwen3 1.7B', quantLabel: 'Q4_K_M', fingerprint: 'f'),
        'qwen3-1.7b-q4_k_m-f',
      );
      expect(
        localIdOf(
          name: 'qwen3-1.7b-q4_k_m',
          quantLabel: 'Q4_K_M',
          fingerprint: 'f',
        ),
        'qwen3-1.7b-q4_k_m-f',
      );
      expect(localIdOf(name: 'Qwen3', fingerprint: 'f'), 'qwen3-f');
      expect(localIdOf(name: '!!!', fingerprint: 'f'), 'f');
    });
  });

  group('inferRepo', () {
    test('reads a Hugging Face cache snapshot', () {
      final repo = inferRepo(
        '/cache',
        '/cache/hub/models--unsloth--Qwen3-8B-GGUF/snapshots/abc123/'
            'Qwen3-8B-Q4_K_M.gguf',
      );

      expect(repo!.repo, 'unsloth/Qwen3-8B-GGUF');
      expect(repo.revision, 'abc123');
    });

    test('reads an org/repo/file layout under the folder', () {
      final repo = inferRepo(
        '/lmstudio/models',
        '/lmstudio/models/lmstudio-community/Qwen3-8B-GGUF/Qwen3-8B.gguf',
      );

      expect(repo!.repo, 'lmstudio-community/Qwen3-8B-GGUF');
      expect(repo.revision, isNull);
    });

    test('reads a split quant one folder deeper', () {
      final repo = inferRepo(
        '/models',
        '/models/unsloth/Big-GGUF/Q8_0/Big-Q8_0-00001-of-00002.gguf',
      );

      expect(repo!.repo, 'unsloth/Big-GGUF');
    });

    test('guesses nothing from other layouts', () {
      expect(inferRepo('/models', '/models/Qwen3.gguf'), isNull);
      expect(inferRepo('/models', '/models/a/b/c/Qwen3.gguf'), isNull);
      expect(
        inferRepo('/models', '/models/a/b/c/d/Big-00001-of-00002.gguf'),
        isNull,
      );
    });
  });
}
