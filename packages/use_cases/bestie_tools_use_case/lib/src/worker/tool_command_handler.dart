import 'package:arxiv_tools/arxiv_tools.dart';
import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:bestie_tools_use_case/src/utility_tools_use_case.dart';
import 'package:bestie_tools_use_case/src/worker/tool_work_request.dart';
import 'package:bestie_tools_use_case/src/worker/toolbox.dart';
import 'package:calculator_tools/calculator_tools.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:intentions/intentions.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:path/path.dart' as p;
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:tool_protocol/tool_protocol.dart';
import 'package:web_fetch_tools/web_fetch_tools.dart';
import 'package:web_search_tools/web_search_tools.dart';
import 'package:wikipedia_tools/wikipedia_tools.dart';

/// Lines of a created file kept for the user to see; the count stays whole.
const createdFileLineCap = 2000;

/// Runs one tool call and renders its outcome.
@PartOf(UtilityToolsUseCase)
final class ToolCommandHandler {
  ToolCommandHandler({
    required ToolWorkerConfig config,
    required ToolboxFactory toolboxFactory,
  }) : _config = config,
       _toolboxFactory = toolboxFactory;

  final ToolWorkerConfig _config;
  final ToolboxFactory _toolboxFactory;

  // Lazy so the toolbox is built on the worker: an assembled toolbox holds
  // an open native library that cannot cross isolates.
  late final Toolbox _toolbox = _toolboxFactory(_config);

  Future<JobOutcome> call(
    ToolWorkRequest request, [
    IsolateRequestContext context = IsolateRequestContext.none,
  ]) async {
    final invocation = request.invocation;
    try {
      return await switch (invocation.toolName) {
        UtilityToolNames.create => _create(request),
        UtilityToolNames.edit => _edit(request),
        UtilityToolNames.webSearch => _webSearch(invocation),
        UtilityToolNames.newsSearch => _newsSearch(invocation),
        UtilityToolNames.webFetch => _webFetch(invocation),
        UtilityToolNames.wikipediaSearch => _wikipediaSearch(invocation),
        UtilityToolNames.arxivSearch => _arxivSearch(invocation),
        UtilityToolNames.calculator => _calculate(invocation),
        UtilityToolNames.dateTime => _now(invocation),
        _ => _noSuchTool(invocation),
      };
    } on Object catch (error) {
      return JobFailed('${error.runtimeType}: $error');
    }
  }

  Future<JobOutcome> _noSuchTool(ToolCallInvocation invocation) async =>
      JobFailed('No such tool: ${invocation.toolName}.');

  Future<JobOutcome> _create(ToolWorkRequest request) async {
    final invocation = request.invocation;
    final path = _string(invocation, 'path') ?? '';
    if (path.isEmpty) return const JobFailed('Path is required.');
    final contents = _string(invocation, 'contents');
    if (contents == null) return const JobFailed('contents is required.');

    final outcome = await _toolbox.fsTools.createFile(
      path: path,
      contents: contents,
      sandbox: request.sandbox,
    );

    return switch (outcome) {
      CreateFileSucceeded(:final path) => JobSucceeded(
        'Created $path (${_lines(_lineCount(contents))}).',
        contributions: [_createdFile(path, contents)],
      ),
      CreateFilePathExists(:final path) => JobFailed(
        'File already exists: $path. Change it with the edit tool.',
      ),
      CreateFileDenied(:final path) => JobFailed(
        _denied('create', path, request.sandbox),
      ),
      CreateFileEditorFailed(:final path, :final reason) => JobFailed(
        'Could not create $path: $reason',
      ),
    };
  }

  /// The new file as the user will see it: the whole of it up to
  /// [createdFileLineCap] lines, counted in full either way.
  CreatedFileContribution _createdFile(String path, String contents) {
    final lines = _lineCount(contents);
    final truncated = lines > createdFileLineCap;
    return CreatedFileContribution(
      path: path,
      text: truncated
          ? contents.split('\n').take(createdFileLineCap).join('\n')
          : contents,
      lines: lines,
      truncated: truncated,
    );
  }

  int _lineCount(String text) => text.isEmpty
      ? 0
      : '\n'.allMatches(text).length + (text.endsWith('\n') ? 0 : 1);

  String _lines(int count) => count == 1 ? '1 line' : '$count lines';

  Future<JobOutcome> _edit(ToolWorkRequest request) async {
    final invocation = request.invocation;
    final path = _string(invocation, 'path') ?? '';
    if (path.isEmpty) return const JobFailed('Path is required.');
    final oldText = _string(invocation, 'old_string') ?? '';
    if (oldText.isEmpty) {
      return const JobFailed('old_string is required and must not be empty.');
    }

    final outcome = await _toolbox.fsTools.editFile(
      path: path,
      oldText: oldText,
      newText: _string(invocation, 'new_string') ?? '',
      replaceAll: invocation.arguments['replace_all'] as bool? ?? false,
      sandbox: request.sandbox,
    );

    return switch (outcome) {
      EditFileSucceeded(:final path, :final diff) => JobSucceeded(
        _editTold(outcome, invocation.maxOutputChars),
        contributions: [DiffContribution(path: path, diff: diff)],
      ),
      EditFileTargetMissing(:final path) => JobFailed(
        'old_string was not found in $path. Read the file again and copy '
        'the text exactly, whitespace included.',
      ),
      EditFileAmbiguous(:final path, :final occurrences) => JobFailed(
        'old_string occurs $occurrences times in $path. Include more of the '
        'surrounding lines so it matches once, or set replace_all.',
      ),
      EditFileNoChange(:final path) => JobFailed(
        'new_string is the same as old_string; $path is unchanged.',
      ),
      EditFilePathMissing(:final path) => JobFailed(
        'File not found: $path. Use the create tool to make a new file.',
      ),
      EditFileIsDirectory(:final path) => JobFailed(
        'Path is a directory, not a file: $path',
      ),
      EditFileDenied(:final path) => JobFailed(
        _denied('edit', path, request.sandbox),
      ),
      EditFileNotText(:final path) => JobFailed('File is not text: $path'),
      EditFileEditorFailed(:final path, :final reason) => JobFailed(
        'Could not edit $path: $reason',
      ),
    };
  }

  /// Why a write was refused: the sandbox, named as such, when the call ran
  /// under one; the file's own permissions otherwise.
  String _denied(String verb, String path, Sandbox? sandbox) {
    if (sandbox == null) return 'Permission denied: could not $verb $path.';
    if (sandbox is ConfinedSandbox && _writableBySandbox(path, sandbox)) {
      return 'The sandbox refused to $verb $path even though it is inside the '
          'working directory: its write grant is missing. Ask the user to '
          'restart, or to run "Sandbox: reset" from the command palette.';
    }
    return 'The sandbox does not allow you to $verb $path. Only files inside '
        'the working directory can be changed, unless the user grants more '
        'through request_write_access.';
  }

  bool _writableBySandbox(String path, ConfinedSandbox sandbox) {
    final absolute = p.normalize(p.join(_config.workingDirectory, path));
    return sandbox.enforcement.writableRoots.any(
      (root) => p.equals(root, absolute) || p.isWithin(root, absolute),
    );
  }

  /// What was replaced and the edited region, with the region giving way
  /// first where the two run past [maxChars].
  String _editTold(EditFileSucceeded outcome, int maxChars) {
    final made = outcome.replacements == 1
        ? 'Replaced 1 occurrence'
        : 'Replaced ${outcome.replacements} occurrences';
    final snippet = Excerpt(
      text: outcome.snippet,
      start: LinePlace.start,
      extent: LinePlace.start.advanced(outcome.snippet),
    );
    return snippet.told(maxChars, (shown) {
      final cut = shown.isWhole ? '' : '\n[snippet cut short]';
      return '$made in ${outcome.path}.\n\n${shown.text}$cut';
    });
  }

  Future<JobOutcome> _webSearch(ToolCallInvocation invocation) async {
    final query = _string(invocation, 'query') ?? '';
    if (query.isEmpty) return const JobFailed('Query is required.');

    final outcome = await _toolbox.webSearchTools.searchWeb(
      query: query,
      storeAt: invocation.outputPath,
      maxResults: _integer(invocation, 'max_results') ?? _defaultMaxResults,
    );

    return switch (outcome) {
      WebSearchSucceeded() => JobSucceeded(
        _pointed(outcome.body, '${outcome.results} results', invocation),
      ),
      WebSearchFoundNothing(:final query) => JobSucceeded(
        'No results found for "$query".',
      ),
    };
  }

  Future<JobOutcome> _newsSearch(ToolCallInvocation invocation) async {
    final query = _string(invocation, 'query') ?? '';
    if (query.isEmpty) return const JobFailed('Query is required.');

    final outcome = await _toolbox.webSearchTools.searchNews(
      query: query,
      storeAt: invocation.outputPath,
      maxResults: _integer(invocation, 'max_results') ?? _defaultMaxResults,
      period: switch (_string(invocation, 'timelimit')) {
        'd' => NewsPeriod.day,
        'm' => NewsPeriod.month,
        _ => NewsPeriod.week,
      },
    );

    return switch (outcome) {
      NewsSearchSucceeded() => JobSucceeded(
        _pointed(outcome.body, '${outcome.results} articles', invocation),
      ),
      NewsSearchFoundNothing(:final query) => JobSucceeded(
        'No news found for "$query".',
      ),
    };
  }

  Future<JobOutcome> _webFetch(ToolCallInvocation invocation) async {
    final url = _string(invocation, 'url') ?? '';
    if (url.isEmpty) return const JobFailed('URL is required.');

    final outcome = await _toolbox.webFetchTools.fetch(
      url: url,
      storeAt: invocation.outputPath,
    );

    return switch (outcome) {
      WebFetchSucceeded(:final title) => JobSucceeded(
        _pointed(outcome.body, title ?? '', invocation),
        contributions: [SourceContribution(url: url, title: title)],
      ),
      WebFetchUrlInvalid(:final url) => JobFailed('Invalid URL: $url.'),
      WebFetchFoundNoContent(:final url) => JobFailed(
        'Could not extract content from $url.',
      ),
      WebFetchFailed(:final url, :final reason) => JobFailed(
        'Failed to fetch $url: $reason',
      ),
    };
  }

  Future<JobOutcome> _wikipediaSearch(ToolCallInvocation invocation) async {
    final query = _string(invocation, 'query') ?? '';
    if (query.isEmpty) return const JobFailed('Query is required.');

    final outcome = await _toolbox.wikipediaTools.search(
      query: query,
      storeAt: invocation.outputPath,
      maxResults: _integer(invocation, 'max_results') ?? _defaultMaxResults,
    );

    return switch (outcome) {
      WikipediaSearchSucceeded() => JobSucceeded(
        _pointed(outcome.body, '${outcome.topics} topics', invocation),
        contributions: [
          for (final source in outcome.sources)
            SourceContribution(url: source.url, title: source.title),
        ],
      ),
      WikipediaSearchFoundNothing(:final query) => JobSucceeded(
        'No Wikipedia results found for "$query".',
      ),
      WikipediaSearchUnavailable(:final reason) => JobFailed(
        'Wikipedia search failed: $reason',
      ),
    };
  }

  Future<JobOutcome> _arxivSearch(ToolCallInvocation invocation) async {
    final query = _string(invocation, 'query') ?? '';
    if (query.isEmpty) return const JobFailed('Query is required.');

    final outcome = await _toolbox.arxivTools.search(
      query: query,
      storeAt: invocation.outputPath,
      maxResults: _integer(invocation, 'max_results') ?? _defaultMaxResults,
      category: _string(invocation, 'category'),
    );

    return switch (outcome) {
      ArxivSearchSucceeded() => JobSucceeded(
        _pointed(outcome.body, '${outcome.papers} papers', invocation),
        contributions: [
          for (final source in outcome.sources)
            SourceContribution(url: source.url, title: source.title),
        ],
      ),
      ArxivSearchFoundNothing(:final query) => JobSucceeded(
        'No arXiv results found for "$query".',
      ),
      ArxivSearchUnavailable(:final reason) => JobFailed(
        'arXiv search failed: $reason',
      ),
    };
  }

  Future<JobOutcome> _calculate(ToolCallInvocation invocation) async {
    final expression = _string(invocation, 'expression') ?? '';
    if (expression.isEmpty) return const JobFailed('Expression is required.');

    return switch (_toolbox.calculator.evaluate(expression)) {
      CalculationSucceeded(:final value) => JobSucceeded(value),
      CalculationFailed(:final reason) => JobFailed(reason),
    };
  }

  Future<JobOutcome> _now(ToolCallInvocation invocation) async =>
      JobSucceeded(_toolbox.dateTime.now().toIso8601String());

  /// [summary] over as much of [stored]'s head as there is room for, with a
  /// note saying where the rest is and the shell command that carries on
  /// from it.
  String _pointed(
    StoredBody stored,
    String summary,
    ToolCallInvocation invocation,
  ) => stored.head.told(invocation.maxOutputChars, (shown) {
    final rest =
        '[${stored.totalChars} chars total, ${stored.totalLines} lines. '
        'Full output: ${stored.storedAt} — '
        "bash: sed -n '${shown.next.line + 1},\$p' '${stored.storedAt}']";
    return [
      if (summary.isNotEmpty) summary,
      if (shown.text.isNotEmpty) shown.text,
      if (!shown.isWhole) rest,
    ].join('\n\n');
  });

  String? _string(ToolCallInvocation invocation, String name) =>
      invocation.arguments[name] as String?;

  int? _integer(ToolCallInvocation invocation, String name) =>
      (invocation.arguments[name] as num?)?.toInt();
}

/// Results a search returns when the caller does not say how many it wants.
const int _defaultMaxResults = 5;
