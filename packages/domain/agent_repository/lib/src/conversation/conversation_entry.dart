import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/conversation/job_in_background.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';

part 'conversation_entry.mapper.dart';

/// One element of the single persisted conversation collection.
@model
@MappableClass(discriminatorKey: 'kind')
sealed class ConversationEntry with ConversationEntryMappable {
  const ConversationEntry({required this.id, required this.timestamp});

  final String id;
  final DateTime timestamp;
}

/// A user / assistant / tool turn-entry.
@model
@MappableClass(discriminatorValue: 'message')
final class MessageEntry extends ConversationEntry with MessageEntryMappable {
  const MessageEntry({
    required super.id,
    required super.timestamp,
    required this.entry,
    required this.responseId,
  });

  /// The authoritative transcript entry; `entry.role` drives whether this is
  /// a user, assistant, or tool row.
  final TranscriptEntry entry;

  /// Groups the entries of a single logical turn into one chat row.
  final int responseId;
}

/// A UI-only system notice (welcome / reset lines).
@model
@MappableClass(discriminatorValue: 'notice')
final class NoticeEntry extends ConversationEntry with NoticeEntryMappable {
  const NoticeEntry({
    required super.id,
    required super.timestamp,
    required this.text,
  });

  final String text;
}

/// A model load/swap, denormalized to baked strings.
@model
@MappableClass(discriminatorValue: 'model_change')
final class ModelChangeEntry extends ConversationEntry
    with ModelChangeEntryMappable {
  const ModelChangeEntry({
    required super.id,
    required super.timestamp,
    required this.modelId,
    required this.displayName,
    required this.contextSize,
    this.provider = legacyModelProvider,
  });

  /// The provider recorded for entries persisted before models were served
  /// remotely; those all ran on the local backend.
  static const legacyModelProvider = 'local';

  final String modelId;
  final String displayName;
  final int contextSize;

  /// Who served the model (e.g. `"OpenRouter"`).
  final String provider;
}

/// A rolling-compaction fold.
@model
@MappableClass(discriminatorValue: 'compaction')
final class CompactionEntry extends ConversationEntry
    with CompactionEntryMappable {
  const CompactionEntry({
    required super.id,
    required super.timestamp,
    required this.summary,
    required this.tokensBefore,
  });

  /// The rolling memory note shown to the model in place of the folded prefix.
  final String summary;

  /// Real prefix-token cost of everything folded into this summary, for the
  /// user-visible "compacted ~N tokens" affordance.
  final int tokensBefore;
}

/// A coalesced batch of completed background jobs delivered to one agent.
@model
@MappableClass(discriminatorValue: 'job_report')
final class JobReportEntry extends ConversationEntry
    with JobReportEntryMappable {
  const JobReportEntry({
    required super.id,
    required super.timestamp,
    required this.responseId,
    required this.reports,
  });

  final int responseId;
  final List<DeliveredJobReport> reports;
}

/// A UI-only row for one call whose work carried on after it answered.
@model
@MappableClass(discriminatorValue: 'job_backgrounded')
final class JobBackgroundedEntry extends ConversationEntry
    with JobBackgroundedEntryMappable {
  const JobBackgroundedEntry({
    required super.id,
    required super.timestamp,
    required this.job,
  });

  final JobInBackground job;
}
