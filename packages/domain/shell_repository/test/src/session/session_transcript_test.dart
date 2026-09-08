// Test file: drives one transcript directly, into the corners the repository
// keeps callers out of.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:shell_repository/src/session/session_transcript.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';

class _MockSurface extends Mock implements TerminalSurface {}

/// Just enough screen to hold lines that have not settled yet.
class _FakeScreen extends Fake implements Screen {
  _FakeScreen(List<String> lines)
    : lines = [
        for (final line in lines)
          LineBytes(
            text: Uint8List.fromList(utf8.encode(line)),
            pen: Uint8List(0),
            units: line.length,
          ),
      ];

  final List<LineBytes> lines;

  int _mutations = 0;

  /// Hands the topmost line to whoever is recording and takes it off screen,
  /// the way history does when the screen scrolls past it.
  void settleFirst() {
    final line = lines.removeAt(0);
    _mutations += 1;
    onEvicted?.call(line.text, line.pen, line.units);
  }

  @override
  List<LineBytes> recordedLines() => List.of(lines);

  @override
  int get mutationCount => _mutations;

  @override
  LineSink? onEvicted;
}

void main() {
  late MemoryFileSystem fileSystem;
  late FilesDataSource files;
  late _MockSurface session;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    files = FilesDataSource(fileSystem: fileSystem, workingDirectory: '/work');
    session = _MockSurface();
    when(() => session.changes).thenAnswer((_) => const Stream<void>.empty());
    when(() => session.screen).thenReturn(_FakeScreen(['on screen']));
  });

  Future<SessionTranscript> recording() async => SessionTranscript(
    session: session,
    record: await files.openRecordFile('out/call-1'),
    endingChars: 100,
  );

  // The file is closed by the first call, so a second one that went looking
  // in it again would be reading through a handle that is gone.
  test('answers with the same ending however often it is asked', () async {
    final transcript = await recording();

    final first = await transcript.finish();
    final second = await transcript.finish();

    expect(first.body.text, 'on screen\n');
    expect(second.body.text, first.body.text);
    expect(second.totalLines, first.totalLines);
  });

  test('has nothing to hand back once it has been abandoned', () async {
    final transcript = await recording();
    await transcript.abandon();

    final ending = await transcript.finish();

    expect(ending.body.text, isEmpty);
    expect(ending.totalLines, 0);
    expect(ending.body.extent.offset, 0);
  });

  test('stops reading the screen once it is abandoned', () async {
    final transcript = await recording();

    await transcript.abandon();

    expect(transcript.lines, 0);
  });

  group('paging', () {
    /// Every page of [transcript] from the start, taken [maxChars] at a time
    /// by carrying on from wherever the last one stopped.
    Future<List<TranscriptPage>> pagesOf(
      SessionTranscript transcript, {
      required int maxChars,
    }) async {
      final pages = <TranscriptPage>[];
      var at = 0;
      // A page that stood still would page forever, so the walk is bounded by
      // the one thing that makes it finite: a character read every time.
      while (at < transcript.chars && pages.length <= transcript.chars) {
        final page = await transcript.window(at: at, length: maxChars);
        pages.add(page);
        if (page.body.next.offset <= at) break;
        at = page.body.next.offset;
      }
      return pages;
    }

    test('walks the whole recording however small the pages are', () async {
      when(
        () => session.screen,
      ).thenReturn(_FakeScreen(['alpha', 'beta', 'gamma', 'delta']));
      final transcript = await recording();
      final whole = await transcript.window(at: 0, length: 1000);

      final pages = await pagesOf(transcript, maxChars: 3);

      expect(pages.map((page) => page.body.text).join(), whole.body.text);
    });

    test('arrives at the end rather than standing still', () async {
      when(
        () => session.screen,
      ).thenReturn(_FakeScreen(['alpha', 'beta', 'gamma', 'delta']));
      final transcript = await recording();

      final pages = await pagesOf(transcript, maxChars: 3);

      expect(pages.last.body.next.offset, transcript.chars);
      expect(pages.last.body.remaining, 0);
    });

    test('reads the same characters after a line settles under it', () async {
      // A line moving off the screen and into the file changes where it is
      // kept, not where it sits in the recording.
      final screen = _FakeScreen(['alpha', 'beta', 'gamma']);
      when(() => session.screen).thenReturn(screen);
      final transcript = await recording();

      final before = await transcript.window(at: 8, length: 5);
      screen.settleFirst();
      final after = await transcript.window(at: 8, length: 5);

      expect(before.body.text, 'ta\nga');
      expect(after.body.text, before.body.text);
      expect(after.body.extent.offset, before.body.extent.offset);
    });

    test('never opens a page on half a character', () async {
      // The end cut to a length that lands between the halves of a pair, so
      // the window has to start after it rather than on it.
      when(() => session.screen).thenReturn(_FakeScreen(['ok', '🐄🐄🐄']));
      final transcript = await recording();

      final page = await transcript.ending(length: 4);

      expect(page.body.text, '🐄\n');
      expect(page.body.start.offset, 7);
    });

    test('is live while the shell is still writing to it', () async {
      final transcript = await recording();

      final page = await transcript.window(at: 0, length: 100);

      expect(page.isLive, isTrue);
    });

    test('is not live once the record has been finished', () async {
      final transcript = await recording();

      final ending = await transcript.finish();

      expect(ending.isLive, isFalse);
    });
  });
}
