// Test file: sequential repository driving.
// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';

class _MockTerminalHost extends Mock implements TerminalHost {}

class _MockAgentTerminal extends Mock implements AgentTerminal {}

/// A repository recording an ephemeral shell, and the parts a test drives it
/// through: its [fileSystem], the [session], and the [screen] it prints to.
class _Recording {
  _Recording(this.repository, this.fileSystem, this.session, this.screen);

  final ShellRepository repository;
  final MemoryFileSystem fileSystem;
  final EphemeralShell session;
  final _FakeScreen screen;
}

class _FakeScreen extends Fake implements Screen {
  _FakeScreen({this.title, List<String> lines = const []})
    : lines = [for (final line in lines) _plain(line)];

  @override
  String? title;

  /// What the shell has put on screen, as `selectionText` would join it,
  /// with whatever pen drew each line.
  final List<LineBytes> lines;

  @override
  List<String> selectionLines() => [
    for (final line in lines) utf8.decode(line.text),
  ];

  @override
  List<LineBytes> recordedLines() => List.of(lines);

  /// Bumped by anything that changes what is on screen, because that is what
  /// tells a recorder its held copy of the live half has gone stale.
  int _mutations = 0;

  @override
  int get mutationCount => _mutations;

  @override
  LineSink? onEvicted;

  /// Hands [line] over as one the screen dropped before the test started
  /// looking, so it is settled without ever having been in [lines].
  void evict(String line) => evictLine(_plain(line));

  /// The same, for a line that was drawn in something other than the
  /// terminal's own pen.
  void evictLine(LineBytes line) {
    _mutations += 1;
    onEvicted?.call(line.text, line.pen, line.units);
  }

  /// Drops the oldest line the way a real screen does once its scrollback
  /// fills: it leaves the screen and is handed over in the same moment, which
  /// is what keeps the record from counting it twice.
  void evictOldest() {
    if (lines.isEmpty) return;
    evictLine(lines.removeAt(0));
  }
}

/// A line drawn in the terminal's own pen, which needs no record of one.
LineBytes _plain(String text) => LineBytes(
  text: Uint8List.fromList(utf8.encode(text)),
  pen: Uint8List(0),
  units: text.length,
);

/// A line the shell drew in red, which is what a plain transcript cannot say.
LineBytes _red(String text) {
  final writer = LineWriter();
  for (final code in text.runes) {
    writer.add(
      code,
      String.fromCharCode,
      fg: packColor(const IndexedColor(9)),
      bg: packedDefaultBg,
      attrs: CellAttrs.none,
    );
  }
  return (writer..end()).take();
}

FilesDataSource _files([MemoryFileSystem? fileSystem]) => FilesDataSource(
  fileSystem: fileSystem ?? MemoryFileSystem.test(),
  workingDirectory: '/work',
);

_MockTerminalHost _hostAnswering(
  Future<TerminalSpawnResult> Function() answer,
) {
  final host = _MockTerminalHost();
  when(
    () => host.spawn(
      executable: any(named: 'executable'),
      arguments: any(named: 'arguments'),
      environment: any(named: 'environment'),
      launchMode: any(named: 'launchMode'),
      rows: any(named: 'rows'),
      cols: any(named: 'cols'),
      scrollbackBytes: any(named: 'scrollbackBytes'),
      forwardHostResize: any(named: 'forwardHostResize'),
    ),
  ).thenAnswer((_) => answer());
  return host;
}

_MockAgentTerminal _liveTerminal({
  Completer<ProcessExit>? exiting,
  String? title,
  _FakeScreen? screen,
  Stream<void>? screenChanges,
}) {
  final terminal = _MockAgentTerminal();
  when(() => terminal.screenChanges).thenAnswer(
    (_) => screenChanges ?? const Stream<void>.empty(),
  );
  when(
    () => terminal.exit,
  ).thenAnswer((_) => (exiting ?? Completer<ProcessExit>()).future);
  when(terminal.close).thenAnswer((_) async {});
  when(() => terminal.screen).thenReturn(screen ?? _FakeScreen(title: title));
  return terminal;
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

const _environment = ShellEnvironment(
  userland: ShellUserland(
    binDir: '/opt/bestie/bin',
    shellPath: '/opt/bestie/bin/brush',
    executables: ShellExecutables.posix,
  ),
  hostEnvironment: {},
  homeDir: '/home/cow',
);

/// The bundled shell every session names.
final _loginShell = ShellSessionRequest.userShell(
  rows: 24,
  cols: 80,
  scrollbackBytes: 10000 * 4096,
  environment: _environment,
);

final _agentShell = ShellSessionRequest.agentShell(
  command: 'ls',
  rows: 24,
  cols: 80,
  scrollbackBytes: 10000 * 4096,
  environment: _environment,
);

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
    registerFallbackValue(ShellLaunchMode.login);
    registerFallbackValue(<String>{});
  });

  group('open', () {
    test('tracks the session under a fresh id', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );

      final first = repository.open(_loginShell);
      final second = repository.open(_loginShell);

      expect(first.id, isNot(second.id));
      expect(repository.sessionFor(first.id), same(first));
      expect(repository.sessionFor(second.id), same(second));
      expect(repository.sessions.map((s) => s.id), [first.id, second.id]);

      await repository.dispose();
    });

    test('an unknown id resolves to nothing', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );

      expect(repository.sessionFor('nope'), isNull);

      await repository.dispose();
    });
  });

  group('roster', () {
    test('publishes each lifecycle transition', () async {
      final exiting = Completer<ProcessExit>();
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(_liveTerminal(exiting: exiting)),
        ),
      );
      final seen = <List<ShellSessionSummary>>[];
      final sub = repository.sessionsStream.listen(seen.add);

      repository.open(_loginShell);
      expect(repository.sessions.single.status, ShellSessionStatus.starting);

      await settle();
      expect(repository.sessions.single.status, ShellSessionStatus.running);

      exiting.complete(const ProcessExited(0));
      await settle();
      expect(repository.sessions.single.status, ShellSessionStatus.exited);

      expect(seen, isNotEmpty);
      await sub.cancel();
      await repository.dispose();
    });

    test('re-publishes when a session retitles itself', () async {
      final changes = StreamController<void>.broadcast();
      final screen = _FakeScreen();
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(
            _liveTerminal(screen: screen, screenChanges: changes.stream),
          ),
        ),
      );
      repository.open(_loginShell);
      await settle();

      final seen = <List<ShellSessionSummary>>[];
      final sub = repository.sessionsStream.listen(seen.add);

      // Output that leaves the title alone does not churn the roster.
      changes.add(null);
      await settle();
      expect(seen.isEmpty, isTrue);

      screen.title = 'vim';
      changes.add(null);
      await settle();
      expect(seen.single.single.title, 'vim');

      await sub.cancel();
      await changes.close();
      await repository.dispose();
    });

    test('carries which lifecycle each session follows', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );

      repository.open(_loginShell);
      await repository.openEphemeral(
        _agentShell,
        path: '/work/out/call-1',
        endingChars: 100,
      );

      expect(repository.sessions.map((s) => s.kind), [
        ShellSessionKind.interactive,
        ShellSessionKind.ephemeral,
      ]);

      await repository.dispose();
    });

    test('a refused spawn shows as failed', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => const TerminalSpawnFailed(
            SpawnFailure(function: 'posix_spawnp', message: 'boom'),
          ),
        ),
      );

      repository.open(_loginShell);
      await settle();

      expect(repository.sessions.single.status, ShellSessionStatus.failed);

      await repository.dispose();
    });
  });

  group('title', () {
    test('prefers whatever the child set', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(_liveTerminal(title: 'vim')),
        ),
      );

      repository.open(_loginShell);
      await settle();

      expect(repository.sessions.single.title, 'vim');

      await repository.dispose();
    });

    test('falls back to what was launched', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(_liveTerminal()),
        ),
      );

      repository.open(
        const ShellSessionRequest(
          executable: 'brush',
          environment: <String, String>{},
          rows: 24,
          cols: 80,
          scrollbackBytes: 0 * 4096,
        ),
      );
      await settle();

      expect(repository.sessions.single.title, 'brush');

      await repository.dispose();
    });

    test('names the binary, not the path it was found at', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );

      repository.open(_loginShell);

      expect(repository.sessions.single.title, 'brush');

      await repository.dispose();
    });

    test('names a session with nothing launched yet', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );

      repository.open(
        const ShellSessionRequest(
          environment: <String, String>{},
          rows: 24,
          cols: 80,
          scrollbackBytes: 100 * 4096,
        ),
      );

      expect(repository.sessions.single.title, 'shell');

      await repository.dispose();
    });
  });

  group('close', () {
    test('disposes the session and drops it from the roster', () async {
      final terminal = _liveTerminal();
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() async => TerminalSpawnSucceeded(terminal)),
      );
      final session = repository.open(_loginShell);
      await settle();

      await repository.close(session.id);

      expect(repository.sessions, isEmpty);
      expect(repository.sessionFor(session.id), isNull);
      verify(terminal.close).called(1);

      await repository.dispose();
    });

    test('an unknown id is a no-op', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );

      await expectLater(repository.close('nope'), completes);

      await repository.dispose();
    });
  });

  group('dispose', () {
    test('closes every session', () async {
      final first = _liveTerminal();
      final second = _liveTerminal();
      var spawns = 0;
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() async {
          spawns++;
          return TerminalSpawnSucceeded(spawns == 1 ? first : second);
        }),
      );
      repository
        ..open(_loginShell)
        ..open(_loginShell);
      await settle();

      await repository.dispose();

      verify(first.close).called(1);
      verify(second.close).called(1);
      expect(repository.sessions, isEmpty);
    });

    test('is idempotent', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );
      repository.open(_loginShell);

      await repository.dispose();

      await expectLater(repository.dispose(), completes);
    });
  });

  group('transcripts', () {
    const path = '/work/out/call-1';

    Future<_Recording> recording(
      List<String> held, {
      int maxChars = 100,
    }) async {
      final fileSystem = MemoryFileSystem.test();
      final screen = _FakeScreen(lines: held);
      final repository = ShellRepository(
        files: _files(fileSystem),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(_liveTerminal(screen: screen)),
        ),
      );
      final session = await repository.openEphemeral(
        _agentShell,
        path: path,
        endingChars: maxChars,
      );
      await settle();
      return _Recording(repository, fileSystem, session, screen);
    }

    /// What the whole recording reads as, less the separator behind its last
    /// line — which the character space counts and nothing printed.
    Future<String> recorded(ShellRepository repository) async {
      final page = await repository.readTranscript(path, length: 100000);
      return page.body.text.endsWith('\n')
          ? page.body.text.substring(0, page.body.text.length - 1)
          : page.body.text;
    }

    test('records what is on screen when nothing was ever dropped', () async {
      final _Recording(:repository, :session) = await recording([
        'aaaa',
        'bbbb',
        'cccc',
      ]);

      final stored = await repository.close(session.id);

      expect(stored.body.text, 'aaaa\nbbbb\ncccc\n');
      expect(stored.totalLines, 3);
      expect(stored.body.isWhole, isTrue);
      expect(await recorded(repository), 'aaaa\nbbbb\ncccc');

      await repository.dispose();
    });

    test(
      'keeps lines the screen dropped, which it can no longer read',
      () async {
        // The whole point: a command that outruns its scrollback loses its own
        // beginning off the screen, so the record has to have taken it earlier.
        final _Recording(:repository, :session, :screen) = await recording([
          'still here',
        ]);

        screen
          ..evict('gone 1')
          ..evict('gone 2');
        final stored = await repository.close(session.id);

        expect(await recorded(repository), 'gone 1\ngone 2\nstill here');
        expect(stored.totalLines, 3);

        await repository.dispose();
      },
    );

    test(
      'answers with the end of the whole record, not just the screen',
      () async {
        final _Recording(:repository, :session, :screen) = await recording([
          'zzzz',
        ], maxChars: 9);

        screen
          ..evict('aaaa')
          ..evict('bbbb');
        final stored = await repository.close(session.id);

        // The end is cut to the allowance rather than back to a line, so the
        // first line of it arrives part-way through.
        expect(stored.body.text, 'bbb\nzzzz\n');
        expect(stored.totalLines, 3);
        expect(stored.body.isWhole, isFalse);
        expect(await recorded(repository), 'aaaa\nbbbb\nzzzz');

        await repository.dispose();
      },
    );

    test('reads back the newest output of a command still running', () async {
      // Answering from the file alone would report no output while the
      // screen is full of it.
      final _Recording(:repository) = await recording(['still going']);

      final page = await repository.readTranscript(path, length: 1000);

      expect(page.body.text, 'still going\n');
      expect(page.totalLines, 1);

      await repository.dispose();
    });

    test('does not write a live line twice when it finally settles', () async {
      // A line read from the screen mid-run is still on the screen, so a
      // record that took a copy then would hold it twice by the end.
      final _Recording(:repository, :session, :screen) = await recording([
        'held',
      ]);
      await repository.readTranscript(path, length: 1000);

      screen.evict('dropped');
      await repository.close(session.id);

      expect(await recorded(repository), 'dropped\nheld');

      await repository.dispose();
    });

    test('reads back mid-run without ending the recording', () async {
      final _Recording(:repository, :session, :screen) = await recording([
        'held',
      ]);
      screen.evict('dropped');

      final page = await repository.readTranscript(path, length: 1000);

      expect(
        page.body.text,
        'dropped\nheld\n',
        reason: 'settled, then on screen',
      );
      expect(page.totalLines, 2);

      screen.evict('dropped later');
      await repository.close(session.id);

      expect(await recorded(repository), 'dropped\ndropped later\nheld');
      await repository.dispose();
    });

    test('stops recording once the session is finished with', () async {
      final _Recording(:repository, :session, :screen) = await recording([
        'held',
      ]);

      await repository.close(session.id);
      screen.evict('too late');

      expect(await recorded(repository), 'held');
      await repository.dispose();
    });

    test('opens as something no plain reader will mistake for text', () async {
      // The magic carries a NUL so a model pointing a file reader at a
      // recording is turned away by machinery that already exists.
      final _Recording(:repository, :fileSystem, :session) = await recording([
        'out',
      ]);

      await repository.close(session.id);

      expect(fileSystem.file(path).readAsBytesSync(), contains(0));
      expect(await _files(fileSystem).looksBinary(path), isTrue);

      await repository.dispose();
    });

    test('keeps the pen beside the text within the one file', () async {
      final _Recording(
        :repository,
        :fileSystem,
        :session,
        :screen,
      ) = await recording([
        'plain tail',
      ]);

      screen.evictLine(_red('dropped in red'));
      await repository.close(session.id);

      expect(await recorded(repository), 'dropped in red\nplain tail');
      expect(
        utf8.decode(await repository.replayTranscript(path)),
        contains('38;5;9'),
        reason: 'the pen the line was drawn in comes back with it',
      );
      expect(fileSystem.directory('/work/out').listSync(), hasLength(1));

      await repository.dispose();
    });

    test('reads back the pen of a line that has settled', () async {
      final _Recording(:repository, :screen) = await recording(['on screen']);
      screen.evictLine(_red('settled'));

      final ansi = utf8.decode(await repository.replayTranscript(path));

      expect(ansi, contains('settled'));
      expect(ansi, contains('on screen'));
      expect(ansi, contains('38;5;9'));

      await repository.dispose();
    });

    test('puts a recorded transcript back on a terminal', () async {
      final _Recording(:repository, :session) = await recording([
        'aaaa',
        'bbbb',
        'cccc',
      ]);
      await repository.close(session.id);

      final surface = await repository.recordedShellFor(
        path,
        rows: 6,
        cols: 20,
      );

      expect(surface.exited, isTrue);
      expect(surface.screen, isNotNull);
      expect(surface.screen!.snapshot().text.trim(), 'aaaa\nbbbb\ncccc');

      await repository.dispose();
    });

    test('reflows a recording to the new width when resized', () async {
      final _Recording(:repository, :session) = await recording([
        'first',
        'second',
      ]);
      await repository.close(session.id);
      final surface = await repository.recordedShellFor(
        path,
        rows: 4,
        cols: 40,
      );

      final changed = surface.changes.first;
      surface.resize(rows: 4, cols: 6);
      await changed;

      expect(surface.screen!.cols, 6);

      await repository.dispose();
    });

    test('reads the settled and the live halves as one sequence', () async {
      final _Recording(:repository, :screen) = await recording([
        'live 1',
        'live 2',
      ]);
      screen
        ..evict('settled 1')
        ..evict('settled 2');

      final page = await repository.readTranscript(path, length: 1000);

      // Every line owns the separator behind it, the last one included, so a
      // window over the whole recording is the whole character space.
      expect(page.body.text, 'settled 1\nsettled 2\nlive 1\nlive 2\n');
      expect(page.body.extent.offset, page.body.text.length);
      expect(page.body.next.offset, page.body.extent.offset);
      expect(page.body.remaining, 0);

      await repository.dispose();
    });

    test('carries on from where the page before it stopped', () async {
      final _Recording(:repository, :screen) = await recording(['live']);
      screen
        ..evict('a')
        ..evict('b')
        ..evict('c');

      final first = await repository.readTranscript(path, length: 4);
      final second = await repository.readTranscript(
        path,
        length: 4,
        at: first.body.next.offset,
      );

      expect(first.body.text, 'a\nb\n');
      expect(second.body.start.offset, first.body.next.offset);
      expect(second.body.text, 'c\nli');
      expect(first.body.text + second.body.text, 'a\nb\nc\nli');

      await repository.dispose();
    });

    test('stops a page at the budget', () async {
      final _Recording(:repository, :screen) = await recording([]);
      screen
        ..evict('aaaa')
        ..evict('bbbb')
        ..evict('cccc');

      final page = await repository.readTranscript(path, length: 9);

      expect(page.body.text, 'aaaa\nbbbb');
      expect(page.body.next.offset, 9);
      expect(page.body.remaining, 6);

      await repository.dispose();
    });

    test('reads a stored record back after its session is gone', () async {
      // The point of keeping the pen on disk: a call whose shell closed long
      // ago can still be put back on a terminal.
      final _Recording(
        :repository,
        :fileSystem,
        :session,
        :screen,
      ) = await recording([
        'on screen',
      ]);
      screen.evictLine(_red('settled'));
      await repository.close(session.id);

      final page = await repository.readTranscript(path, length: 1000);

      expect(page.body.text, 'settled\non screen\n');
      expect(page.totalLines, 2);
      expect(
        utf8.decode(await repository.replayTranscript(path)),
        contains('38;5;9'),
      );
      expect(fileSystem.file(path).existsSync(), isTrue);

      await repository.dispose();
    });

    test('pages a stored record from anywhere in it', () async {
      final _Recording(:repository, :session, :screen) = await recording([
        'live',
      ]);
      screen
        ..evict('a')
        ..evict('b');
      await repository.close(session.id);

      final page = await repository.readTranscript(path, length: 2, at: 2);

      expect(page.body.text, 'b\n');
      expect(page.body.start.offset, 2);
      expect(page.body.next.offset, 4);
      expect(page.body.remaining, 5);

      await repository.dispose();
    });

    test('reads an empty record where nothing was ever stored', () async {
      final _Recording(:repository) = await recording(['held']);

      final page = await repository.readTranscript(
        '/work/out/missing',
        length: 100,
      );

      expect(page.body.text, isEmpty);
      expect(page.totalLines, 0);
      expect(await repository.replayTranscript('/work/out/missing'), isEmpty);

      await repository.dispose();
    });

    test('reads nothing out of a file that is not a recording', () async {
      final fileSystem = MemoryFileSystem.test();
      fileSystem.file('/work/out/old')
        ..createSync(recursive: true)
        ..writeAsStringSync('one\ntwo');
      final repository = ShellRepository(
        files: _files(fileSystem),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );

      final page = await repository.readTranscript(
        '/work/out/old',
        length: 100,
      );

      expect(page.body.text, isEmpty);
      expect(page.totalLines, 0);

      await repository.dispose();
    });

    test('closing a session it does not know records nothing', () async {
      final _Recording(:repository) = await recording(['held']);

      expect((await repository.close('nope')).totalLines, 0);

      await repository.dispose();
    });

    test('records nothing for a session that never spawned', () async {
      final fileSystem = MemoryFileSystem.test();
      final repository = ShellRepository(
        files: _files(fileSystem),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );
      final session = await repository.openEphemeral(
        _agentShell,
        path: path,
        endingChars: 100,
      );

      final stored = await repository.close(session.id);

      expect(stored.totalLines, 0);
      expect(await recorded(repository), isEmpty);

      await repository.dispose();
    });

    test('closing keeps what it recorded, live screen and all', () async {
      final _Recording(:repository, :session, :screen) = await recording([
        'held',
      ]);
      screen.evict('dropped');

      await repository.close(session.id);
      screen.evict('too late');

      expect(await recorded(repository), 'dropped\nheld');
      await repository.dispose();
    });

    test('disposing gives up every recording it still holds', () async {
      final _Recording(:repository, :fileSystem, :screen) = await recording([
        'held',
      ]);
      screen.evict('dropped');

      await repository.dispose();
      screen.evict('too late');

      final files = _files(fileSystem);
      expect(
        (await files.openRecords(path))!.records,
        1,
        reason: 'what had settled is readable; what was live is not',
      );
    });
  });

  group('ephemeral lifecycle', () {
    const path = '/work/out/call-1';

    test('reaps itself on exit and hands back its record', () async {
      final exiting = Completer<ProcessExit>();
      final screen = _FakeScreen(lines: ['done']);
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(
            _liveTerminal(exiting: exiting, screen: screen),
          ),
        ),
      );
      final session = await repository.openEphemeral(
        _agentShell,
        path: path,
        endingChars: 100,
      );
      await settle();
      expect(repository.runningEphemeralShells, 1);

      exiting.complete(const ProcessExited(0));
      final page = await session.transcriptPage;

      expect(page.body.text, 'done\n');
      expect(repository.sessionFor(session.id), isNull);
      expect(repository.runningEphemeralShells, 0);

      await repository.dispose();
    });

    test('close reaps early and its record still resolves', () async {
      final screen = _FakeScreen(lines: ['partial']);
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(_liveTerminal(screen: screen)),
        ),
      );
      final session = await repository.openEphemeral(
        _agentShell,
        path: path,
        endingChars: 100,
      );
      await settle();

      final returned = await repository.close(session.id);
      final resolved = await session.transcriptPage;

      expect(returned.body.text, 'partial\n');
      expect(resolved.body.text, 'partial\n');
      expect(repository.sessionFor(session.id), isNull);

      await repository.dispose();
    });

    test('counts only live ephemeral shells', () async {
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(() => Completer<TerminalSpawnResult>().future),
      );
      repository.open(_loginShell);
      await repository.openEphemeral(
        _agentShell,
        path: '/work/out/a',
        endingChars: 100,
      );
      await repository.openEphemeral(
        _agentShell,
        path: '/work/out/b',
        endingChars: 100,
      );

      expect(repository.runningEphemeralShells, 2);

      await repository.dispose();
    });

    test('leaves an interactive shell tracked when it exits', () async {
      final exiting = Completer<ProcessExit>();
      final repository = ShellRepository(
        files: _files(),
        host: _hostAnswering(
          () async => TerminalSpawnSucceeded(_liveTerminal(exiting: exiting)),
        ),
      );
      final session = repository.open(_loginShell);
      await settle();

      exiting.complete(const ProcessExited(0));
      await settle();

      expect(repository.sessionFor(session.id), same(session));
      expect(repository.sessions.single.status, ShellSessionStatus.exited);

      await repository.dispose();
    });
  });
}
