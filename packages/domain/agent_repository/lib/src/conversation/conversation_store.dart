import 'dart:convert';

import 'package:agent_repository/src/agent/agent_session_id.dart';
import 'package:agent_repository/src/conversation/agent_session_data.dart';
import 'package:agent_repository/src/conversation/conversation_summary.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;

/// Persists conversations as a directory per conversation holding a directory
/// per agent. Sole owner of everything under [conversationsDir].
@dataSource
class ConversationStore {
  ConversationStore({
    required this.conversationsDir,
    required this.fileSystem,
  });

  final String conversationsDir;
  final FileSystem fileSystem;

  /// Path context matching [fileSystem]'s style.
  p.Context get _path => fileSystem.path;

  /// Writes [session], replacing what is there. The bytes land in a temporary
  /// file that is renamed over the real one, so a reader never sees a
  /// half-written session and a write that dies partway leaves the previous
  /// one intact.
  Future<void> save(AgentSessionData session) async {
    final dir = _agentDir(session.conversationId, session.agentId);
    await fileSystem.directory(dir).create(recursive: true);
    final path = _path.join(dir, _sessionFileName);
    final pending = fileSystem.file('$path$_pendingSuffix');
    await pending.writeAsString(jsonEncode(session.toMap()));
    await pending.rename(path);
  }

  Future<AgentSessionData?> load(
    String conversationId, {
    required String agentId,
  }) async {
    final file = fileSystem.file(
      _path.join(_agentDir(conversationId, agentId), _sessionFileName),
    );
    if (!file.existsSync()) return null;
    final contents = await file.readAsString();
    final json = jsonDecode(contents) as Map<String, Object?>;
    return AgentSessionDataMapper.fromMap(json);
  }

  /// Every conversation with a readable primary session, in no particular
  /// order. Directories whose primary session is missing or unreadable are
  /// left out rather than failing the whole listing.
  Future<List<ConversationSummary>> summaries() async {
    final dir = fileSystem.directory(conversationsDir);
    if (!dir.existsSync()) return const [];

    final summaries = <ConversationSummary>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final data = await _loadQuietly(_path.basename(entity.path));
      if (data == null) continue;
      summaries.add(ConversationSummary.fromSessionData(data));
    }
    return summaries;
  }

  Future<AgentSessionData?> _loadQuietly(String conversationId) async {
    try {
      return await load(conversationId, agentId: primaryAgentSessionId);
    } on Object catch (_) {
      return null;
    }
  }

  /// Removes a conversation whole.
  Future<void> delete(String conversationId) async {
    final dir = fileSystem.directory(_conversationDir(conversationId));
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  /// Where a tool call may write.
  String toolOutputPath({
    required String conversationId,
    required String agentId,
    required String callId,
  }) => _path.join(_agentDir(conversationId, agentId), 'tools', callId);

  static const _sessionFileName = 'session.json';

  /// Extension of the half-written file a [save] renames into place.
  static const _pendingSuffix = '.tmp';

  String _conversationDir(String conversationId) =>
      _path.join(conversationsDir, conversationId);

  String _agentDir(String conversationId, String agentId) =>
      _path.join(_conversationDir(conversationId), agentId);
}
