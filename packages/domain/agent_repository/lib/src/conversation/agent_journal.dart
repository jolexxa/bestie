import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_repository/src/agent/agent_repository.dart';
import 'package:agent_repository/src/conversation/agent_session_data.dart';
import 'package:agent_repository/src/conversation/agent_transcript.dart';
import 'package:agent_repository/src/conversation/conversation_entry.dart';
import 'package:agent_repository/src/conversation/conversation_store.dart';
import 'package:agent_repository/src/conversation/job_report.dart';
import 'package:agent_repository/src/message/timeline_fold.dart';
import 'package:agent_repository/src/message/timeline_item.dart';
import 'package:diagnostics/diagnostics.dart';
import 'package:intentions/intentions.dart';

/// The single place one agent's history changes, and the only writer to its
/// [ConversationStore] file.
///
/// Every mutation schedules a write, so history that exists in memory is
/// always on its way to disk; [flush] waits for what is outstanding. Writes
/// are serialized and coalesced, so a burst of appends costs one save carrying
/// the newest snapshot, and two saves of the same file never overlap.
@PartOf(AgentRepository)
final class AgentJournal implements AgentTranscript {
  AgentJournal._({
    required this.conversationId,
    required this.agentId,
    required this.workingDirectory,
    required this.createdAt,
    required DateTime updatedAt,
    required List<ConversationEntry> entries,
    required ConversationStore store,
  }) : _updatedAt = updatedAt,
       _entries = entries,
       _store = store;

  /// A fresh journal for [agentId]. Without [conversationId] it starts a new
  /// conversation, named for the moment it began.
  factory AgentJournal.fresh({
    required String agentId,
    required String workingDirectory,
    required ConversationStore store,
    String? conversationId,
  }) {
    final now = DateTime.now();
    return AgentJournal._(
      conversationId: conversationId ?? now.millisecondsSinceEpoch.toString(),
      agentId: agentId,
      workingDirectory: workingDirectory,
      createdAt: now,
      updatedAt: now,
      entries: [],
      store: store,
    );
  }

  /// Resumes from persisted [data].
  factory AgentJournal.fromSessionData(
    AgentSessionData data, {
    required ConversationStore store,
  }) => AgentJournal._(
    conversationId: data.conversationId,
    agentId: data.agentId,
    workingDirectory: data.workingDirectory,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
    entries: [...data.entries],
    store: store,
  );

  @override
  final String conversationId;

  @override
  final String agentId;

  @override
  final String workingDirectory;

  @override
  final DateTime createdAt;

  @override
  DateTime get updatedAt => _updatedAt;
  DateTime _updatedAt;

  final ConversationStore _store;
  final List<ConversationEntry> _entries;
  final TranscriptId _transcriptId = TranscriptId.v7();

  /// Summary-checkpoint entries by [CompactionEntry] id.
  final Map<String, TranscriptEntry> _checkpoints = {};

  /// Synthesized report entries by [JobReportEntry] id, so a report's
  /// `TranscriptEntryId` stays stable across reads.
  final Map<String, TranscriptEntry> _reportEntries = {};

  /// The writes scheduled so far, run one after another.
  Future<void> _writes = Future.value();

  /// Whether a write is already queued to pick up the newest snapshot.
  bool _writeQueued = false;

  @override
  List<ConversationEntry> get entries => List.unmodifiable(_entries);

  @override
  Transcript get transcript {
    final entries = [
      for (final entry in _entries)
        switch (entry) {
          MessageEntry(:final entry) => entry,
          CompactionEntry(:final id, :final summary) =>
            _checkpoints.putIfAbsent(id, () => _summaryCheckpoint(summary)),
          JobReportEntry(:final id, :final reports) =>
            _reportEntries.putIfAbsent(
              id,
              () => _jobReportEntry(reports),
            ),
          ModelChangeEntry() ||
          NoticeEntry() ||
          JobBackgroundedEntry() => null, // UI-only.
        },
    ].nonNulls.toList();
    return Transcript(
      id: _transcriptId,
      revision: entries.length,
      entries: entries,
    );
  }

  @override
  List<TimelineItem> get timeline => foldTimeline(_entries);

  @override
  bool get isEmpty => _entries.isEmpty;

  @override
  bool get hasFoldableHistory => transcript.hasFoldableEntries;

  @override
  String? userMessageText(String entryId) {
    final entry = _entries
        .whereType<MessageEntry>()
        .where((entry) => entry.id == entryId && entry.entry.role == Role.user)
        .firstOrNull;
    if (entry == null) return null;
    return entry.entry.blocks
        .whereType<TranscriptParagraphBlock>()
        .map((block) => block.text)
        .join();
  }

  // ── Mutation ──────────────────────────────────────────

  /// Appends one entry and schedules the write that durably records it.
  void append(ConversationEntry entry) {
    _entries.add(entry);
    _touch();
  }

  /// Appends a model card, taking the place of one already at the tail so
  /// a stretch of history never shows two cards in a row.
  void recordModelChange(ModelChangeEntry entry) {
    if (_entries.lastOrNull is ModelChangeEntry) _entries.removeLast();
    append(entry);
  }

  /// Cuts history back to just before the entry [entryId], reporting whether
  /// any entry carried that id.
  bool truncateBefore(String entryId) {
    final index = _entries.indexWhere((entry) => entry.id == entryId);
    if (index < 0) return false;
    _entries.removeRange(index, _entries.length);
    _touch();
    return true;
  }

  // ── Persistence ───────────────────────────────────────

  /// The persistable projection.
  AgentSessionData toSessionData() => AgentSessionData(
    conversationId: conversationId,
    agentId: agentId,
    workingDirectory: workingDirectory,
    createdAt: createdAt,
    updatedAt: updatedAt,
    entries: List.of(_entries),
  );

  /// Completes once every write scheduled so far has landed.
  Future<void> flush() => _writes;

  void _touch() {
    _updatedAt = DateTime.now();
    if (_writeQueued) return;
    _writeQueued = true;
    _writes = _writes.then((_) => _write());
  }

  /// Writes the snapshot as it stands now. Taking it here rather than when the
  /// write was scheduled is what lets a burst of mutations settle into one
  /// save. A failure is reported and dropped: the next write reattempts, and
  /// the chain must stay usable.
  Future<void> _write() async {
    _writeQueued = false;
    if (_entries.isEmpty) return;
    try {
      await _store.save(toSessionData());
    } on Object catch (error) {
      Diagnostics.log(
        'journal',
        'save failed for $conversationId/$agentId: $error',
      );
    }
  }

  static TranscriptEntry _summaryCheckpoint(String summary) => TranscriptEntry(
    id: TranscriptEntryId.v7(),
    role: Role.system,
    blocks: [TranscriptSummaryBlock(id: TranscriptBlockId.v7(), text: summary)],
  );

  static TranscriptEntry _jobReportEntry(List<DeliveredJobReport> reports) =>
      TranscriptEntry(
        id: TranscriptEntryId.v7(),
        role: Role.user,
        blocks: [
          TranscriptParagraphBlock(
            id: TranscriptBlockId.v7(),
            text: composeJobReportText(reports),
          ),
        ],
      );
}
