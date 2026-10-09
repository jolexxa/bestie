/// How the model panes word what the library and Hugging Face report.
library;

import 'package:command_protocol/command_protocol.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';

/// The prompt formats bestie runs, for explaining what it can't.
const runnableFamilies = 'qwen2/3/3.5, gpt-oss, gemma4 and glm4';

/// Why a GGUF on disk can't run, in one line.
String unsupportedLabel(UnsupportedReason reason) => switch (reason) {
  ArchitectureUnsupported(:final architecture) =>
    'Not supported yet: $architecture architecture',
  TemplateUnrecognized() => 'Unsupported model type',
  NotAChatModel(:final task) =>
    "Not supported: it's ${_taskKind(task)}, not a chat model",
  QuantUnsupported(:final fileType) =>
    'Not supported: unknown quantization (file type $fileType)',
  MetadataMissing(:final key) => 'Not supported: the header has no $key',
  HeaderUnreadable(:final reason) => "Can't read the GGUF header: $reason",
  ShardsMissing(:final found, :final expected) =>
    'Missing parts: found $found of $expected files',
};

/// Why nothing in a repo can run, short enough for a search result.
String unrunnableLabel(UnrunnableReason reason) => switch (reason) {
  ArchitectureUnsupported(:final architecture) =>
    "$architecture isn't supported yet",
  TemplateUnrecognized() => 'unsupported model type',
  NotAChatModel(:final task) => '${_taskKind(task)}, not a chat model',
  NoGgufFiles() => 'it has no GGUF files',
  NoSupportedQuants() => 'none of its quants are ones bestie runs',
};

/// What a model the Hub files under [task] is.
String _taskKind(String task) => switch (task) {
  'feature-extraction' || 'sentence-similarity' => 'an embedding model',
  'text-ranking' => 'a reranker',
  _ => "made for ${task.replaceAll('-', ' ')}",
};

/// Why nothing in a repo can run, as the lines under the quant pane's
/// heading.
List<PaneNote> unrunnableNotes(UnrunnableReason reason) => switch (reason) {
  ArchitectureUnsupported(:final architecture) => [
    PaneNote([
      const PaneSpan('  Architecture ', PaneTone.muted),
      PaneSpan(architecture),
      const PaneSpan(" isn't supported. Bestie runs", PaneTone.muted),
    ]),
    const PaneNote([
      PaneSpan('  $runnableFamilies models today.', PaneTone.muted),
    ]),
  ],
  TemplateUnrecognized() => const [
    PaneNote([PaneSpan('  Unsupported model type.', PaneTone.muted)]),
  ],
  NotAChatModel(:final task) => [
    PaneNote([
      PaneSpan(
        '  This is ${_taskKind(task)}, not a chat model.',
        PaneTone.muted,
      ),
    ]),
    const PaneNote([
      PaneSpan('  Bestie only runs chat models.', PaneTone.muted),
    ]),
  ],
  NoGgufFiles() => const [
    PaneNote([PaneSpan('  The repo has no GGUF files.', PaneTone.muted)]),
  ],
  NoSupportedQuants(:final labels) => [
    PaneNote([
      PaneSpan(
        labels.isEmpty
            ? '  None of its files name a quantization bestie knows.'
            : "  Its quants (${labels.join(', ')}) aren't ones bestie runs.",
        PaneTone.muted,
      ),
    ]),
  ],
};

/// A download's name: its repo's, without the `-GGUF` every GGUF repo
/// carries.
String downloadName(String repo) => repo
    .split('/')
    .last
    .replaceFirst(RegExp(r'[-_.]gguf$', caseSensitive: false), '');

/// The display name of the model [localId] names in [library], or the id
/// itself when the library doesn't list it.
String modelName(ModelLibrary library, String localId) =>
    library.modelById(localId)?.displayName ?? localId;

/// The tier's name and the tone it reads in.
PaneSpan tierSpan(QualityTier tier) => PaneSpan(tier.name, switch (tier) {
  QualityTier.overkill => PaneTone.highlight,
  QualityTier.great => PaneTone.success,
  QualityTier.good => PaneTone.info,
  QualityTier.mediocre => PaneTone.warning,
  QualityTier.bad || QualityTier.awful => PaneTone.danger,
});

/// The fit's name and the tone it reads in.
PaneSpan fitSpan(ModelFit fit) => switch (fit) {
  ModelFit.fits => const PaneSpan('fits', PaneTone.success),
  ModelFit.tight => const PaneSpan('tight', PaneTone.warning),
  ModelFit.tooBig => const PaneSpan('too big', PaneTone.danger),
};

/// What the model can do about reasoning.
String reasoningLabel(ModelReasoning reasoning) => switch (reasoning) {
  ModelReasoningNone() => "Doesn't reason",
  ModelReasoningAlways() => 'Always reasons',
  ModelReasoningToggle() => 'On by default · can be turned off',
  ModelReasoningEfforts(:final efforts) => 'Effort: ${efforts.join(', ')}',
};

/// The sampling the GGUF recommends, or null when it recommends none.
String? samplingLabel(ModelSamplingDefaults sampling) {
  final parts = [
    if (sampling.temperature case final temperature?) 'temp $temperature',
    if (sampling.topP case final topP?) 'top_p $topP',
    if (sampling.topK case final topK?) 'top_k $topK',
    if (sampling.minP case final minP?) 'min_p $minP',
    if (sampling.penaltyRepeat case final penaltyRepeat?)
      'repeat_penalty $penaltyRepeat',
    if (sampling.penaltyLastN case final penaltyLastN?)
      'repeat_last_n $penaltyLastN',
  ];
  return parts.isEmpty ? null : '${parts.join(' · ')} (from the GGUF)';
}

/// Why this window can't change downloads right now.
String downloadsUnavailableReason(DownloadsStatus status) => switch (status) {
  DownloadsStarting() => 'Downloads are still starting up',
  DownloadsManagedElsewhere() =>
    'Another bestie window runs downloads; use that one',
  DownloadsLedgerUnreadable(:final reason) =>
    "Downloads are paused: the download list can't be read ($reason)",
  DownloadsReady() ||
  DownloadsLedgerSetAside() ||
  DownloadsLedgerNotSaved() => 'Downloads are unavailable right now',
};
