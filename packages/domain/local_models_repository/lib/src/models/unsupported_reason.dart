import 'package:intentions/intentions.dart';

/// Why a GGUF on disk cannot be run.
@model
sealed class UnsupportedReason {
  const UnsupportedReason();
}

/// Why nothing in a Hugging Face repo can be run.
@model
sealed class UnrunnableReason {
  const UnrunnableReason();
}

/// No prompt format bestie knows fits the model.
@model
sealed class ProfileUnavailable implements UnsupportedReason, UnrunnableReason {
  const ProfileUnavailable(this.architecture);

  /// As the GGUF header names it, e.g. `granitehybrid`.
  final String architecture;
}

/// No prompt format bestie knows covers the model's architecture.
@model
final class ArchitectureUnsupported extends ProfileUnavailable {
  const ArchitectureUnsupported(super.architecture);
}

/// The architecture is one bestie runs, but the chat template is not in the
/// format bestie would prompt it with, as with a fine-tune that brought its
/// own template, or there is no template at all.
@model
final class TemplateUnrecognized extends ProfileUnavailable {
  const TemplateUnrecognized(super.architecture);
}

/// The header names a quantization bestie does not know.
@model
final class QuantUnsupported extends UnsupportedReason {
  const QuantUnsupported(this.fileType);

  /// The header's `general.file_type`.
  final int fileType;
}

/// A header key every runnable model carries is missing.
@model
final class MetadataMissing extends UnsupportedReason {
  const MetadataMissing(this.key);

  final String key;
}

@model
final class HeaderUnreadable extends UnsupportedReason {
  const HeaderUnreadable(this.reason);

  final String reason;
}

/// Some files of a split model are not next to the first one.
@model
final class ShardsMissing extends UnsupportedReason {
  const ShardsMissing({required this.found, required this.expected});

  final int found;

  final int expected;
}

/// The model does something other than write text, such as embeddings or
/// reranking.
@model
final class NotAChatModel implements UnsupportedReason, UnrunnableReason {
  const NotAChatModel(this.task);

  /// What it does, as a Hub pipeline tag, e.g. `feature-extraction`.
  final String task;
}

@model
final class NoGgufFiles extends UnrunnableReason {
  const NoGgufFiles();
}

/// The repo has GGUFs, but only in quantizations bestie cannot run.
@model
final class NoSupportedQuants extends UnrunnableReason {
  const NoSupportedQuants(this.labels);

  /// The quant labels the repo offers; empty when no file names one.
  final List<String> labels;
}
