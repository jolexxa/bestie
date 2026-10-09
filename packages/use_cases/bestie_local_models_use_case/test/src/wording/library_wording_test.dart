import 'package:bestie_local_models_use_case/src/wording/library_wording.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  test('unsupportedLabel says why a GGUF on disk cannot run', () {
    expect(
      unsupportedLabel(const ArchitectureUnsupported('granitehybrid')),
      'Not supported yet: granitehybrid architecture',
    );
    expect(
      unsupportedLabel(const TemplateUnrecognized('qwen3')),
      'Unsupported model type',
    );
    expect(
      unsupportedLabel(const NotAChatModel('feature-extraction')),
      "Not supported: it's an embedding model, not a chat model",
    );
    expect(
      unsupportedLabel(const NotAChatModel('text-ranking')),
      "Not supported: it's a reranker, not a chat model",
    );
    expect(
      unsupportedLabel(const QuantUnsupported(99)),
      'Not supported: unknown quantization (file type 99)',
    );
    expect(
      unsupportedLabel(const MetadataMissing('general.architecture')),
      'Not supported: the header has no general.architecture',
    );
    expect(
      unsupportedLabel(const HeaderUnreadable('truncated')),
      "Can't read the GGUF header: truncated",
    );
    expect(
      unsupportedLabel(const ShardsMissing(found: 2, expected: 3)),
      'Missing parts: found 2 of 3 files',
    );
  });

  test('unrunnableLabel fits a search result', () {
    expect(
      unrunnableLabel(const ArchitectureUnsupported('gemma4v')),
      "gemma4v isn't supported yet",
    );
    expect(
      unrunnableLabel(const TemplateUnrecognized('qwen3')),
      'unsupported model type',
    );
    expect(
      unrunnableLabel(const NotAChatModel('feature-extraction')),
      'an embedding model, not a chat model',
    );
    expect(
      unrunnableLabel(const NotAChatModel('sentence-similarity')),
      'an embedding model, not a chat model',
    );
    expect(
      unrunnableLabel(const NotAChatModel('text-ranking')),
      'a reranker, not a chat model',
    );
    expect(
      unrunnableLabel(const NotAChatModel('text-to-speech')),
      'made for text to speech, not a chat model',
    );
    expect(unrunnableLabel(const NoGgufFiles()), 'it has no GGUF files');
    expect(
      unrunnableLabel(const NoSupportedQuants(['Q9'])),
      'none of its quants are ones bestie runs',
    );
  });

  group('unrunnableNotes', () {
    test('names the architecture and what bestie runs instead', () {
      final notes = unrunnableNotes(const ArchitectureUnsupported('gemma4v'));
      expect(notes.map(noteText), [
        "  Architecture gemma4v isn't supported. Bestie runs",
        '  qwen2/3/3.5, gpt-oss, gemma4 and glm4 models today.',
      ]);
    });

    test('calls an unrecognized chat template an unsupported model type', () {
      expect(
        unrunnableNotes(const TemplateUnrecognized('qwen3')).map(noteText),
        ['  Unsupported model type.'],
      );
    });

    test('says what the model is for and that bestie runs chat', () {
      expect(
        unrunnableNotes(const NotAChatModel('text-ranking')).map(noteText),
        [
          '  This is a reranker, not a chat model.',
          '  Bestie only runs chat models.',
        ],
      );
      expect(
        unrunnableNotes(
          const NotAChatModel('automatic-speech-recognition'),
        ).map(noteText).first,
        '  This is made for automatic speech recognition, not a chat model.',
      );
    });

    test('says the repo has no GGUF files', () {
      expect(unrunnableNotes(const NoGgufFiles()).map(noteText), [
        '  The repo has no GGUF files.',
      ]);
    });

    test('lists the quants bestie does not run', () {
      expect(
        unrunnableNotes(const NoSupportedQuants(['Q4_X', 'Q9'])).map(noteText),
        ["  Its quants (Q4_X, Q9) aren't ones bestie runs."],
      );
      expect(
        unrunnableNotes(const NoSupportedQuants([])).map(noteText),
        ['  None of its files name a quantization bestie knows.'],
      );
    });
  });

  test('downloadName drops the -GGUF suffix and the owner', () {
    expect(downloadName('openai/gpt-oss-20b-GGUF'), 'gpt-oss-20b');
    expect(downloadName('unsloth/Qwen3-8B_gguf'), 'Qwen3-8B');
    expect(downloadName('owner/plain'), 'plain');
  });

  test('tierSpan tones each tier', () {
    expect(
      {for (final tier in QualityTier.values) tier.name: tierSpan(tier).tone},
      {
        'overkill': PaneTone.highlight,
        'great': PaneTone.success,
        'good': PaneTone.info,
        'mediocre': PaneTone.warning,
        'bad': PaneTone.danger,
        'awful': PaneTone.danger,
      },
    );
    expect(tierSpan(QualityTier.great).text, 'great');
  });

  test('fitSpan names and tones each fit', () {
    expect(
      [for (final fit in ModelFit.values) fitSpan(fit)].map(
        (span) => '${span.text}:${span.tone.name}',
      ),
      ['fits:success', 'tight:warning', 'too big:danger'],
    );
  });

  test('reasoningLabel says what the model can do about reasoning', () {
    expect(reasoningLabel(const ModelReasoningNone()), "Doesn't reason");
    expect(reasoningLabel(const ModelReasoningAlways()), 'Always reasons');
    expect(
      reasoningLabel(const ModelReasoningToggle()),
      'On by default · can be turned off',
    );
    expect(
      reasoningLabel(const ModelReasoningEfforts(efforts: ['low', 'high'])),
      'Effort: low, high',
    );
  });

  test('samplingLabel lists what the GGUF recommends', () {
    expect(
      samplingLabel(
        const ModelSamplingDefaults(
          temperature: 0.6,
          topP: 0.95,
          topK: 20,
          minP: 0,
          penaltyRepeat: 1.05,
          penaltyLastN: 128,
        ),
      ),
      'temp 0.6 · top_p 0.95 · top_k 20 · min_p 0.0 · repeat_penalty 1.05 · '
      'repeat_last_n 128 (from the GGUF)',
    );
    expect(samplingLabel(const ModelSamplingDefaults()), isNull);
  });

  test('downloadsUnavailableReason says why downloads cannot change', () {
    expect(
      downloadsUnavailableReason(const DownloadsStarting()),
      'Downloads are still starting up',
    );
    expect(
      downloadsUnavailableReason(const DownloadsManagedElsewhere()),
      'Another bestie window runs downloads; use that one',
    );
    expect(
      downloadsUnavailableReason(const DownloadsLedgerUnreadable('bad json')),
      "Downloads are paused: the download list can't be read (bad json)",
    );
    for (final status in const <DownloadsStatus>[
      DownloadsReady(),
      DownloadsLedgerSetAside(reason: 'bad', movedTo: '/x'),
      DownloadsLedgerNotSaved('disk full'),
    ]) {
      expect(
        downloadsUnavailableReason(status),
        'Downloads are unavailable right now',
      );
    }
  });
}
