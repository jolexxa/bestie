import 'dart:async';

import 'package:bestie_tools_use_case/src/routing/tool_router.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// One unsettled job and the call that created it.
@model
final class JobEntry {
  const JobEntry({
    required this.call,
    required this.conversationId,
    required this.agentId,
    required this.job,
  });

  final ToolCall call;
  final String conversationId;
  final String agentId;
  final Job job;
}

/// Router-private ownership of every unsettled tool job.
@PartOf(ToolRouter)
final class JobManager {
  final Map<String, JobEntry> _entries = {};
  final _changes = StreamController<List<JobEntry>>.broadcast();

  Stream<List<JobEntry>> get jobs => _changes.stream;

  void add(JobEntry entry) {
    _entries[_key(entry)] = entry;
    _emit();
    unawaited(
      entry.job.settled.whenComplete(() {
        final key = _key(entry);
        if (identical(_entries[key], entry)) {
          _entries.remove(key);
          _emit();
        }
      }),
    );
  }

  List<JobEntry> get entries => List.unmodifiable(_entries.values);

  /// Stops every held job. Settled jobs no-op.
  void stopAll() {
    for (final entry in _entries.values.toList()) {
      entry.job.stop();
    }
  }

  Future<void> dispose() => _changes.close();

  void _emit() {
    if (!_changes.isClosed) _changes.add(entries);
  }

  String _key(JobEntry entry) => '${entry.agentId}/${entry.call.id}';
}
