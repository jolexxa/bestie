import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/src/chat_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Turns the saved conversations into palette options and answers the
/// user's search over them. Built once per palette flow, so the listing is
/// read from disk once and every keystroke filters in memory.
@PartOf(ChatUseCase)
final class ConversationPicker {
  ConversationPicker({
    required Future<List<ConversationSummary>> summaries,
    required this.homeDirectory,
    required this.currentConversationId,
  }) : _summaries = summaries;

  final Future<List<ConversationSummary>> _summaries;

  /// Shown as `~` at the front of a working directory.
  final String homeDirectory;

  /// Left out of the listing: it is already loaded.
  final String currentConversationId;

  /// The most recently updated conversations first, narrowed to those where
  /// every whitespace-separated term of [query] appears in the row or in the
  /// conversation's own prose. Conversations the user never spoke in are
  /// left out.
  Stream<List<Option<String>>> search(String query) =>
      Stream.fromFuture(_summaries.then((all) => _options(all, query)));

  List<Option<String>> _options(
    List<ConversationSummary> all,
    String query,
  ) {
    final terms = query
        .toLowerCase()
        .split(_whitespace)
        .where(
          (term) => term.isNotEmpty,
        );
    final listed =
        all
            .where(
              (summary) =>
                  summary.hasUserMessage && summary.id != currentConversationId,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return [
      for (final summary in listed)
        if (_matches(summary, terms)) _option(summary),
    ];
  }

  bool _matches(ConversationSummary summary, Iterable<String> terms) {
    final haystack = '${_label(summary).toLowerCase()} ${summary.searchText}';
    return terms.every(haystack.contains);
  }

  Option<String> _option(ConversationSummary summary) => Option(
    value: summary.id,
    label: _label(summary),
    detail: snippet(summary.firstUserMessage),
  );

  String _label(ConversationSummary summary) =>
      '${shortPath(summary.workingDirectory)} · '
      '${timestamp(summary.updatedAt)}';

  /// [path] with a leading [homeDirectory] shown as `~`.
  String shortPath(String path) {
    if (path == homeDirectory) return '~';
    for (final separator in const ['/', r'\']) {
      final prefix = '$homeDirectory$separator';
      if (path.startsWith(prefix)) {
        return '~$separator${path.substring(prefix.length)}';
      }
    }
    return path;
  }

  /// Local `yyyy-MM-dd HH:mm`.
  static String timestamp(DateTime when) {
    final local = when.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// [text] on one line, cut to [snippetLength] characters.
  static String snippet(String text) {
    final line = text.replaceAll(_whitespace, ' ').trim();
    if (line.length <= snippetLength) return line;
    return '${line.substring(0, snippetLength - 1)}…';
  }

  static const int snippetLength = 80;

  static final RegExp _whitespace = RegExp(r'\s+');
}
