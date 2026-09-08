import 'package:arxiv_tools/arxiv_tools.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:calculator_tools/calculator_tools.dart';
import 'package:clock/clock.dart';
import 'package:date_time_tools/date_time_tools.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:sandbox/sandbox.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';
import 'package:web_fetch_tools/web_fetch_tools.dart';
import 'package:web_search_tools/web_search_tools.dart';
import 'package:wikipedia_tools/wikipedia_tools.dart';

class _MockFsTools extends Mock implements FsTools {}

class _MockWebSearchTools extends Mock implements WebSearchTools {}

class _MockWebFetchTools extends Mock implements WebFetchTools {}

class _MockWikipediaTools extends Mock implements WikipediaTools {}

class _MockArxivTools extends Mock implements ArxivTools {}

class _MockCalculator extends Mock implements Calculator {}

class _FakeSandbox implements Sandbox {}

/// A confinement that says the worker's `/work` is writable.
class _ConfinedFakeSandbox implements ConfinedSandbox {
  @override
  SandboxEnforcement get enforcement => const SandboxEnforcement(
    enforced: {SandboxCapability.filesystemWrite},
    writableRoots: ['/work'],
    network: NetworkConfined(NetworkTier.none),
    backend: 'fake',
  );
}

ToolWorkRequest _request(
  String toolName, {
  Map<String, Object?> arguments = const {},
  int maxOutputChars = 4000,
  Sandbox? sandbox,
}) => ToolWorkRequest(
  ToolCallInvocation(
    conversationId: 'conversation',
    agentId: 'agent',
    callId: 'call-1',
    toolName: toolName,
    outputPath: 'output',
    maxOutputChars: maxOutputChars,
    arguments: arguments,
  ),
  sandbox: sandbox,
);

/// A stored body whose head is [head], of [totalChars] characters and
/// [totalLines] lines in all — the whole of it when neither is given.
StoredBody _body({
  required String head,
  int? totalChars,
  int? totalLines,
  String storedAt = '/store/output',
}) {
  final chars = totalChars ?? head.length;
  return StoredBody(
    head: Excerpt.lines(
      head,
      extent: chars == head.length
          ? LinePlace.start.advanced(head)
          : LinePlace(line: (totalLines ?? 1) - 1, into: 1),
    ),
    totalChars: chars,
    storedAt: storedAt,
  );
}

Future<String> _content(Future<JobOutcome> outcome) async =>
    (await outcome as JobSucceeded).content;

Future<String> _message(Future<JobOutcome> outcome) async =>
    (await outcome as JobFailed).message;

const _workerConfig = ToolWorkerConfig(
  workingDirectory: '/work',
  curlLibraryPath: '/curl',
  caCertPath: '/ca.pem',
  editorPath: '/bestie_edit',
  processHost: PosixProcessHostLocation(spawnerBinaryPath: '/spawner'),
);

void main() {
  late _MockFsTools fsTools;
  late _MockWebSearchTools webSearchTools;
  late _MockWebFetchTools webFetchTools;
  late _MockWikipediaTools wikipediaTools;
  late _MockArxivTools arxivTools;
  late _MockCalculator calculator;

  // The tool set is what the production factory would have built inside the
  // worker, so the handler is exercised with no isolate in the picture.
  ToolCommandHandler handlerWith() => ToolCommandHandler(
    config: _workerConfig,
    toolboxFactory: (_) => Toolbox(
      fsTools: fsTools,
      webSearchTools: webSearchTools,
      webFetchTools: webFetchTools,
      wikipediaTools: wikipediaTools,
      arxivTools: arxivTools,
      calculator: calculator,
      dateTime: const DateTimeTools(),
    ),
  );

  setUpAll(() {
    registerFallbackValue(NewsPeriod.week);
    registerFallbackValue(_FakeSandbox());
  });

  setUp(() {
    fsTools = _MockFsTools();
    webSearchTools = _MockWebSearchTools();
    webFetchTools = _MockWebFetchTools();
    wikipediaTools = _MockWikipediaTools();
    arxivTools = _MockArxivTools();
    calculator = _MockCalculator();
  });

  group('dispatch', () {
    // Shared name constants stop the two sides being spelled differently;
    // only this stops a tool being offered and then never answered.
    test('answers every tool the feature offers', () async {
      for (final definition in utilityToolDefinitions) {
        expect(
          await handlerWith().call(_request(definition.name)),
          isNot(
            isA<JobFailed>().having(
              (failure) => failure.message,
              'message',
              contains('No such tool'),
            ),
          ),
          reason: '${definition.name} is offered but has no case to answer it',
        );
      }
    });

    test('fails a call naming a tool it does not have', () async {
      expect(
        await _message(handlerWith().call(_request('missing'))),
        contains('No such tool: missing'),
      );
    });
  });

  group('what an answer may cost', () {
    void searchAnswers(StoredBody body, {int results = 5}) {
      when(
        () => webSearchTools.searchWeb(
          query: any(named: 'query'),
          storeAt: any(named: 'storeAt'),
          maxResults: any(named: 'maxResults'),
        ),
      ).thenAnswer(
        (_) async => WebSearchSucceeded(
          query: 'cows',
          body: body,
          results: results,
        ),
      );
    }

    Future<String> search(int maxOutputChars) => _content(
      handlerWith().call(
        _request(
          'web_search',
          arguments: const {'query': 'cows'},
          maxOutputChars: maxOutputChars,
        ),
      ),
    );

    // Summary and pointer quote paths and totals of any size that nothing
    // counted beforehand, and the answer must still fit the allowance.
    test('holds summary, body and pointer inside the allowance', () async {
      final deep = '/home/${'deeply/nested/' * 30}store';
      final listing = List.generate(
        400,
        (at) => '$at. Result $at — https://example.com/$at',
      ).join('\n');
      searchAnswers(
        _body(
          head: listing,
          totalChars: 999999999,
          totalLines: 9999999,
          storedAt: '$deep/output/call-1',
        ),
        results: 9999999,
      );

      final content = await search(2000);

      expect(content.length, lessThanOrEqualTo(2000));
      expect(content, startsWith('9999999 results'));
      expect(content, contains('999999999 chars total'));
      expect(content, contains('$deep/output/call-1'));
    });

    test('sends a reader back to a line it was actually shown', () async {
      final listing = List.generate(400, (at) => 'line $at').join('\n');
      searchAnswers(_body(head: listing, totalChars: 99999, totalLines: 9000));

      final content = await search(600);

      // Wherever the head stopped is the line the reader is sent back to,
      // whole — a line cut partway is shown again rather than lost.
      final shown = content.split('\n\n')[1];
      final stopped = LinePlace.start.advanced(shown);
      expect(
        content,
        endsWith("bash: sed -n '${stopped.line + 1},\$p' '/store/output']"),
      );
    });

    test('gives up the body entirely before it gives up the wording', () async {
      // Where even the wording overruns, the answer keeps saying where the
      // rest is; the router's backstop fails a call that cannot be told.
      final deep = '/home/${'deeply/nested/' * 30}store';
      final listing = List.generate(400, (at) => 'line $at').join('\n');
      searchAnswers(
        _body(
          head: listing,
          totalChars: 99999,
          totalLines: 9000,
          storedAt: deep,
        ),
      );

      final content = await search(100);

      expect(content, isNot(contains('line 0')));
      expect(content, startsWith('5 results'));
      expect(content, contains("sed -n '1,\$p' '$deep'"));
    });
  });

  group('create', () {
    void answerWith(CreateFileOutcome outcome) {
      when(
        () => fsTools.createFile(
          path: any(named: 'path'),
          contents: any(named: 'contents'),
          sandbox: any(named: 'sandbox'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    Future<JobOutcome> call({
      Map<String, Object?> arguments = const {
        'path': 'lib/a.dart',
        'contents': 'one\ntwo\n',
      },
      Sandbox? sandbox,
    }) => handlerWith().call(
      _request('create', arguments: arguments, sandbox: sandbox),
    );

    test('reports the file and carries its text for the user', () async {
      answerWith(const CreateFileSucceeded('lib/a.dart'));

      final outcome = await call() as JobSucceeded;

      expect(outcome.content, 'Created lib/a.dart (2 lines).');
      expect(outcome.contributions, [
        const CreatedFileContribution(
          path: 'lib/a.dart',
          text: 'one\ntwo\n',
          lines: 2,
        ),
      ]);
    });

    test('counts lines whether or not the file ends in a newline', () async {
      answerWith(const CreateFileSucceeded('a'));

      expect(
        await _content(call(arguments: const {'path': 'a', 'contents': 'x'})),
        'Created a (1 line).',
      );
      expect(
        await _content(call(arguments: const {'path': 'a', 'contents': ''})),
        'Created a (0 lines).',
      );
    });

    test(
      'keeps the head of a long file for the user, counting it all',
      () async {
        answerWith(const CreateFileSucceeded('big.txt'));
        final contents = List.generate(2500, (at) => 'line $at').join('\n');

        final outcome = await call(
          arguments: {'path': 'big.txt', 'contents': contents},
        );

        final created =
            (outcome as JobSucceeded).contributions.single
                as CreatedFileContribution;
        expect(created.lines, 2500);
        expect(created.truncated, isTrue);
        expect(created.text.split('\n'), hasLength(createdFileLineCap));
        expect(created.text, endsWith('line 1999'));
        expect(outcome.content, 'Created big.txt (2500 lines).');
      },
    );

    test('passes the arguments and the confinement down', () async {
      answerWith(const CreateFileSucceeded('lib/a.dart'));
      final sandbox = _FakeSandbox();

      await call(sandbox: sandbox);

      verify(
        () => fsTools.createFile(
          path: 'lib/a.dart',
          contents: 'one\ntwo\n',
          sandbox: sandbox,
        ),
      ).called(1);
    });

    test('names the sandbox when it was the one refusing', () async {
      answerWith(const CreateFileDenied('/etc/hosts'));

      expect(
        await _message(call(sandbox: _FakeSandbox())),
        allOf(
          contains('The sandbox does not allow you to create /etc/hosts'),
          contains('working directory'),
        ),
      );
    });

    test('blames the path when a confinement refuses outside it', () async {
      answerWith(const CreateFileDenied('/etc/hosts'));

      expect(
        await _message(call(sandbox: _ConfinedFakeSandbox())),
        contains('The sandbox does not allow you to create /etc/hosts'),
      );
    });

    test(
      'blames the missing grant when a confinement refuses inside it',
      () async {
        answerWith(const CreateFileDenied('lib/a.dart'));

        expect(
          await _message(call(sandbox: _ConfinedFakeSandbox())),
          allOf(
            contains('refused to create lib/a.dart'),
            contains('write grant is missing'),
            contains('Sandbox: reset'),
          ),
        );
      },
    );

    test('requires a path and contents, empty contents included', () async {
      answerWith(const CreateFileSucceeded('a'));

      expect(
        await _message(call(arguments: const {'contents': 'x'})),
        'Path is required.',
      );
      expect(
        await _message(call(arguments: const {'path': 'a'})),
        'contents is required.',
      );
      await call(arguments: const {'path': 'a', 'contents': ''});

      verify(
        () => fsTools.createFile(
          path: 'a',
          contents: '',
          sandbox: any(named: 'sandbox'),
        ),
      ).called(1);
    });

    test(
      'tells the model what to do about every way it can go wrong',
      () async {
        final cases = <CreateFileOutcome, Matcher>{
          const CreateFilePathExists('lib/a.dart'): allOf(
            contains('File already exists: lib/a.dart'),
            contains('edit tool'),
          ),
          const CreateFileDenied('/etc/hosts'): allOf(
            contains('Permission denied: could not create /etc/hosts'),
            isNot(contains('sandbox')),
          ),
          const CreateFileEditorFailed('lib/a.dart', reason: 'boom'): contains(
            'Could not create lib/a.dart: boom',
          ),
        };

        for (final entry in cases.entries) {
          answerWith(entry.key);
          expect(await _message(call()), entry.value, reason: '${entry.key}');
        }
      },
    );
  });

  group('edit', () {
    const diff = FileDiff(hunks: [], added: 1, removed: 1);

    void answerWith(EditFileOutcome outcome) {
      when(
        () => fsTools.editFile(
          path: any(named: 'path'),
          oldText: any(named: 'oldText'),
          newText: any(named: 'newText'),
          replaceAll: any(named: 'replaceAll'),
          sandbox: any(named: 'sandbox'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    Future<JobOutcome> call({
      Map<String, Object?> arguments = const {
        'path': 'a.dart',
        'old_string': 'cow',
        'new_string': 'bull',
      },
      Sandbox? sandbox,
      int maxOutputChars = 4000,
    }) => handlerWith().call(
      _request(
        'edit',
        arguments: arguments,
        sandbox: sandbox,
        maxOutputChars: maxOutputChars,
      ),
    );

    test(
      'reports the replacement, shows the region, and carries the diff',
      () async {
        answerWith(
          const EditFileSucceeded(
            'a.dart',
            replacements: 1,
            snippet: '     1\tbull',
            diff: diff,
          ),
        );

        final outcome = await call() as JobSucceeded;

        expect(
          outcome.content,
          'Replaced 1 occurrence in a.dart.\n\n     1\tbull',
        );
        expect(outcome.contributions, [
          const DiffContribution(path: 'a.dart', diff: diff),
        ]);
      },
    );

    test('counts more than one replacement', () async {
      answerWith(
        const EditFileSucceeded(
          'a.dart',
          replacements: 3,
          snippet: 'x',
          diff: diff,
        ),
      );

      expect(await _content(call()), startsWith('Replaced 3 occurrences'));
    });

    test('lets the region give way before the wording', () async {
      answerWith(
        EditFileSucceeded(
          'a.dart',
          replacements: 1,
          snippet: List.generate(400, (at) => 'line $at').join('\n'),
          diff: diff,
        ),
      );

      final content = await _content(call(maxOutputChars: 300));

      expect(content.length, lessThanOrEqualTo(300));
      expect(content, startsWith('Replaced 1 occurrence in a.dart.'));
      expect(content, endsWith('[snippet cut short]'));
    });

    test('passes the arguments and the confinement down', () async {
      answerWith(const EditFileNoChange('a.dart'));
      final sandbox = _FakeSandbox();

      await call(
        arguments: const {
          'path': 'a.dart',
          'old_string': 'cow',
          'new_string': 'bull',
          'replace_all': true,
        },
        sandbox: sandbox,
      );

      verify(
        () => fsTools.editFile(
          path: 'a.dart',
          oldText: 'cow',
          newText: 'bull',
          replaceAll: true,
          sandbox: sandbox,
        ),
      ).called(1);
    });

    test('runs unconfined when no sandbox came along', () async {
      answerWith(const EditFileNoChange('a.dart'));

      await call();

      final sent = verify(
        () => fsTools.editFile(
          path: 'a.dart',
          oldText: 'cow',
          newText: 'bull',
          replaceAll: captureAny(named: 'replaceAll'),
          sandbox: captureAny(named: 'sandbox'),
        ),
      ).captured;
      expect(sent, [false, null]);
    });

    test('names the sandbox when it was the one refusing', () async {
      answerWith(const EditFileDenied('/etc/hosts'));

      expect(
        await _message(call(sandbox: _FakeSandbox())),
        allOf(
          contains('The sandbox does not allow you to edit /etc/hosts'),
          contains('working directory'),
        ),
      );
    });

    test('requires a path and a non-empty old_string', () async {
      expect(
        await _message(call(arguments: const {'old_string': 'cow'})),
        'Path is required.',
      );
      expect(
        await _message(call(arguments: const {'path': 'a.dart'})),
        'old_string is required and must not be empty.',
      );
      expect(
        await _message(
          call(arguments: const {'path': 'a.dart', 'old_string': ''}),
        ),
        'old_string is required and must not be empty.',
      );
      verifyNever(
        () => fsTools.editFile(
          path: any(named: 'path'),
          oldText: any(named: 'oldText'),
          newText: any(named: 'newText'),
          replaceAll: any(named: 'replaceAll'),
          sandbox: any(named: 'sandbox'),
        ),
      );
    });

    test(
      'tells the model what to do about every way it can go wrong',
      () async {
        final cases = <EditFileOutcome, Matcher>{
          const EditFileTargetMissing('a.dart'): allOf(
            contains('old_string was not found in a.dart'),
            contains('Read the file again'),
          ),
          const EditFileAmbiguous('a.dart', occurrences: 4): allOf(
            contains('occurs 4 times in a.dart'),
            contains('replace_all'),
          ),
          const EditFileNoChange('a.dart'): contains('a.dart is unchanged'),
          const EditFilePathMissing('a.dart'): allOf(
            contains('File not found: a.dart'),
            contains('create tool'),
          ),
          const EditFileIsDirectory('a'): contains(
            'Path is a directory, not a file: a',
          ),
          const EditFileDenied('/etc/hosts'): allOf(
            contains('Permission denied: could not edit /etc/hosts'),
            isNot(contains('sandbox')),
          ),
          const EditFileNotText('a.bin'): contains('File is not text: a.bin'),
          const EditFileEditorFailed('a.dart', reason: 'boom'): contains(
            'Could not edit a.dart: boom',
          ),
        };

        for (final entry in cases.entries) {
          answerWith(entry.key);
          expect(await _message(call()), entry.value, reason: '${entry.key}');
        }
      },
    );
  });

  group('web_search', () {
    void answerWith(WebSearchOutcome outcome) {
      when(
        () => webSearchTools.searchWeb(
          query: any(named: 'query'),
          storeAt: any(named: 'storeAt'),
          maxResults: any(named: 'maxResults'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    Future<JobOutcome> call([
      Map<String, Object?> arguments = const {'query': 'cows'},
    ]) => handlerWith().call(
      _request('web_search', arguments: arguments),
    );

    test('counts the results and points at the whole set', () async {
      answerWith(
        WebSearchSucceeded(
          query: 'cows',
          body: _body(head: '1. Cows', totalChars: 900, totalLines: 20),
          results: 5,
        ),
      );

      final content = await _content(call());

      expect(content, startsWith('5 results'));
      expect(content, contains('1. Cows'));
      expect(content, contains('900 chars total, 20 lines'));
    });

    test('says so when nothing matched', () async {
      answerWith(const WebSearchFoundNothing(query: 'cows'));

      expect(await _content(call()), 'No results found for "cows".');
    });

    test('requires a query', () async {
      expect(await _message(call(const {})), 'Query is required.');
    });

    test('defaults the result count and passes an explicit one down', () async {
      answerWith(const WebSearchFoundNothing(query: 'cows'));

      await call();
      await call(const {'query': 'cows', 'max_results': 9});

      verify(
        () => webSearchTools.searchWeb(
          query: 'cows',
          storeAt: 'output',
          maxResults: any(named: 'maxResults', that: equals(5)),
        ),
      ).called(1);
      verify(
        () => webSearchTools.searchWeb(
          query: 'cows',
          storeAt: 'output',
          maxResults: 9,
        ),
      ).called(1);
    });
  });

  group('news_search', () {
    void answerWith(NewsSearchOutcome outcome) {
      when(
        () => webSearchTools.searchNews(
          query: any(named: 'query'),
          storeAt: any(named: 'storeAt'),
          maxResults: any(named: 'maxResults'),
          period: any(named: 'period'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    Future<JobOutcome> call([
      Map<String, Object?> arguments = const {'query': 'cows'},
    ]) => handlerWith().call(
      _request('news_search', arguments: arguments),
    );

    test('counts the articles', () async {
      answerWith(
        NewsSearchSucceeded(
          query: 'cows',
          body: _body(head: '1. Cows in the news'),
          results: 3,
        ),
      );

      expect(await _content(call()), startsWith('3 articles'));
    });

    test('says so when nothing matched', () async {
      answerWith(const NewsSearchFoundNothing(query: 'cows'));

      expect(await _content(call()), 'No news found for "cows".');
    });

    test('reads the time filter, and defaults it to a week', () async {
      answerWith(const NewsSearchFoundNothing(query: 'cows'));

      await call();
      await call(const {'query': 'cows', 'timelimit': 'd'});
      await call(const {'query': 'cows', 'timelimit': 'm'});

      verify(
        () => webSearchTools.searchNews(
          query: 'cows',
          storeAt: 'output',
          maxResults: any(named: 'maxResults'),
          period: any(named: 'period', that: equals(NewsPeriod.week)),
        ),
      ).called(1);
      verify(
        () => webSearchTools.searchNews(
          query: 'cows',
          storeAt: 'output',
          maxResults: any(named: 'maxResults'),
          period: NewsPeriod.day,
        ),
      ).called(1);
      verify(
        () => webSearchTools.searchNews(
          query: 'cows',
          storeAt: 'output',
          maxResults: any(named: 'maxResults'),
          period: NewsPeriod.month,
        ),
      ).called(1);
    });
  });

  group('web_fetch', () {
    void answerWith(WebFetchOutcome outcome) {
      when(
        () => webFetchTools.fetch(
          url: any(named: 'url'),
          storeAt: any(named: 'storeAt'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    Future<JobOutcome> call([
      Map<String, Object?> arguments = const {'url': 'https://cows.example'},
    ]) => handlerWith().call(
      _request('web_fetch', arguments: arguments),
    );

    test('heads the page and credits it as a source', () async {
      answerWith(
        WebFetchSucceeded(
          url: 'https://cows.example',
          title: 'All About Cows',
          body: _body(head: 'Cows are', totalChars: 5000, totalLines: 90),
        ),
      );

      final outcome = await call() as JobSucceeded;

      expect(outcome.content, startsWith('All About Cows'));
      expect(outcome.content, contains('5000 chars total'));
      expect(
        outcome.contributions.whereType<SourceContribution>().single.url,
        'https://cows.example',
      );
    });

    test('maps every way it can go wrong', () async {
      answerWith(const WebFetchUrlInvalid(url: '::'));
      expect(await _message(call()), 'Invalid URL: ::.');

      answerWith(const WebFetchFoundNoContent(url: 'https://cows.example'));
      expect(await _message(call()), contains('Could not extract content'));

      answerWith(
        const WebFetchFailed(url: 'https://cows.example', reason: 'timed out'),
      );
      expect(await _message(call()), contains('timed out'));
    });

    test('requires a url', () async {
      expect(await _message(call(const {})), 'URL is required.');
    });
  });

  group('wiki_search', () {
    void answerWith(WikipediaSearchOutcome outcome) {
      when(
        () => wikipediaTools.search(
          query: any(named: 'query'),
          storeAt: any(named: 'storeAt'),
          maxResults: any(named: 'maxResults'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    Future<JobOutcome> call([
      Map<String, Object?> arguments = const {'query': 'cows'},
    ]) => handlerWith().call(
      _request('wiki_search', arguments: arguments),
    );

    test('counts the topics and credits each as a source', () async {
      answerWith(
        WikipediaSearchSucceeded(
          query: 'cows',
          body: _body(head: '1. Cattle'),
          topics: 2,
          sources: const [
            TopicSource(url: 'https://wiki/Cattle', title: 'Cattle'),
            TopicSource(url: 'https://wiki/Dairy', title: 'Dairy'),
          ],
        ),
      );

      final outcome = await call() as JobSucceeded;

      expect(
        outcome.content,
        startsWith('2 topics'),
      );
      expect(
        outcome.contributions.whereType<SourceContribution>().map(
          (source) => source.title,
        ),
        ['Cattle', 'Dairy'],
      );
    });

    test('maps every way it can go wrong', () async {
      answerWith(const WikipediaSearchFoundNothing(query: 'cows'));
      expect(
        await _content(call()),
        'No Wikipedia results found for "cows".',
      );

      answerWith(
        const WikipediaSearchUnavailable(query: 'cows', reason: 'down'),
      );
      expect(await _message(call()), 'Wikipedia search failed: down');
    });

    test('requires a query', () async {
      expect(await _message(call(const {})), 'Query is required.');
    });
  });

  group('arxiv_search', () {
    void answerWith(ArxivSearchOutcome outcome) {
      when(
        () => arxivTools.search(
          query: any(named: 'query'),
          storeAt: any(named: 'storeAt'),
          maxResults: any(named: 'maxResults'),
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    Future<JobOutcome> call([
      Map<String, Object?> arguments = const {'query': 'cows'},
    ]) => handlerWith().call(
      _request('arxiv_search', arguments: arguments),
    );

    test('counts the papers and credits each as a source', () async {
      answerWith(
        ArxivSearchSucceeded(
          query: 'cows',
          body: _body(head: '1. On Cows'),
          papers: 1,
          sources: const [
            PaperSource(url: 'https://arxiv.org/abs/1', title: 'On Cows'),
          ],
        ),
      );

      final outcome = await call() as JobSucceeded;

      expect(
        outcome.content,
        startsWith('1 papers'),
      );
      expect(
        outcome.contributions.whereType<SourceContribution>().single.title,
        'On Cows',
      );
    });

    test('maps every way it can go wrong', () async {
      answerWith(const ArxivSearchFoundNothing(query: 'cows'));
      expect(await _content(call()), 'No arXiv results found for "cows".');

      answerWith(
        const ArxivSearchUnavailable(query: 'cows', reason: 'down'),
      );
      expect(await _message(call()), 'arXiv search failed: down');
    });

    test('passes the category filter down', () async {
      answerWith(const ArxivSearchFoundNothing(query: 'cows'));

      await call(const {'query': 'cows', 'category': 'cs.AI'});

      verify(
        () => arxivTools.search(
          query: 'cows',
          storeAt: 'output',
          maxResults: any(named: 'maxResults'),
          category: 'cs.AI',
        ),
      ).called(1);
    });

    test('requires a query', () async {
      expect(await _message(call(const {})), 'Query is required.');
    });
  });

  group('calculator', () {
    Future<JobOutcome> call([
      Map<String, Object?> arguments = const {'expression': '2 ^ 10'},
    ]) => handlerWith().call(
      _request('calculator', arguments: arguments),
    );

    test('answers with the value', () async {
      when(
        () => calculator.evaluate(any()),
      ).thenReturn(const CalculationSucceeded('1024'));

      expect(await _content(call()), '1024');
    });

    test('fails with the reason it could not evaluate', () async {
      when(
        () => calculator.evaluate(any()),
      ).thenReturn(const CalculationFailed('Unknown operator'));

      expect(await _message(call()), 'Unknown operator');
    });

    test('requires an expression', () async {
      expect(await _message(call(const {})), 'Expression is required.');
    });
  });

  group('date_time', () {
    test('answers with the wall clock in ISO 8601', () async {
      final fixed = DateTime(2026, 8, 9, 14, 30);

      final content = await withClock(
        Clock.fixed(fixed),
        () => _content(handlerWith().call(_request('date_time'))),
      );

      expect(content, fixed.toIso8601String());
    });
  });

  test('turns a throwing tool into a failed job', () async {
    when(() => calculator.evaluate(any())).thenThrow(StateError('boom'));

    expect(
      await _message(
        handlerWith().call(
          _request('calculator', arguments: const {'expression': '1'}),
        ),
      ),
      contains('boom'),
    );
  });
}
