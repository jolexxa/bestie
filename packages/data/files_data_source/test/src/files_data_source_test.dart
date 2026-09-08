import 'dart:convert';
import 'dart:typed_data';

import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:test/test.dart';

Uint8List _bytes(String text) => Uint8List.fromList(text.codeUnits);

void main() {
  late MemoryFileSystem fileSystem;
  late FilesDataSource files;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory('/work').createSync(recursive: true);
    files = FilesDataSource(fileSystem: fileSystem, workingDirectory: '/work');
  });

  void write(String path, String contents) {
    fileSystem.file(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  FilesDataSource keeping(int headCacheChars) => FilesDataSource(
    fileSystem: fileSystem,
    workingDirectory: '/work',
    headCacheChars: headCacheChars,
  );

  group('factsOf', () {
    test('answers with an absolute path for a relative one', () async {
      write('/work/notes.txt', 'hi');

      final facts = await files.factsOf('notes.txt');

      expect(facts?.path, '/work/notes.txt');
      expect(facts?.kind, FileKind.file);
      expect(facts?.size, 2);
    });

    test('names a directory as one', () async {
      fileSystem.directory('/work/src').createSync();

      expect((await files.factsOf('src'))?.kind, FileKind.directory);
    });

    test('is null when nothing is there', () async {
      expect(await files.factsOf('missing.txt'), isNull);
    });

    test('names a link as one, sized as what it points at', () async {
      write('/work/notes.txt', 'hello');
      fileSystem.link('/work/shortcut').createSync('/work/notes.txt');

      final facts = await files.factsOf('shortcut');

      expect(facts?.kind, FileKind.link);
      expect(facts?.size, 5, reason: 'reading the path reads the target');
    });
  });

  group('looksBinary', () {
    test('is false for text', () async {
      write('/work/notes.txt', 'plain text');

      expect(await files.looksBinary('notes.txt'), isFalse);
    });

    test('is true for content holding a null byte', () async {
      fileSystem.file('/work/blob.bin').writeAsBytesSync([1, 2, 0, 3]);

      expect(await files.looksBinary('blob.bin'), isTrue);
    });

    test('is true for something that cannot be opened', () async {
      expect(await files.looksBinary('missing.bin'), isTrue);
    });
  });

  group('extentOf', () {
    test('counts lines and bytes', () async {
      write('/work/notes.txt', 'one\ntwo\nthree');

      final extent = await files.extentOf('notes.txt');

      expect(extent.lines, 3);
      expect(extent.bytes, 13);
    });
  });

  group('readLines', () {
    test('windows from a line, each line carrying its newline', () async {
      write('/work/notes.txt', 'a\nb\nc\nd');

      final page = await files.readLines(
        'notes.txt',
        at: const LinePlace(line: 1),
        limit: 2,
      );

      expect(page.text, 'b\nc\n');
      expect(page.next, const LinePlace(line: 3));
      expect(page.extent, const LinePlace(line: 3, into: 1));
      expect(page.remaining, 1);
    });

    test('reads the whole file without a limit', () async {
      write('/work/notes.txt', 'a\nb');

      final page = await files.readLines('notes.txt');

      expect(page.text, 'a\nb');
      expect(page.isWhole, isTrue);
    });

    test('a trailing newline reads back, landing past the last line', () async {
      write('/work/notes.txt', 'a\nb\n');

      final page = await files.readLines('notes.txt');

      expect(page.text, 'a\nb\n');
      expect(page.next, const LinePlace(line: 2));
      expect(page.isWhole, isTrue);
    });

    test('carries on inside a line, replaying its newline', () async {
      write('/work/notes.txt', 'abcdef\ng');

      final page = await files.readLines(
        'notes.txt',
        at: const LinePlace(line: 0, into: 4),
      );

      expect(page.text, 'ef\ng');
      expect(page.start, const LinePlace(line: 0, into: 4));
      expect(page.isWhole, isFalse, reason: 'a resumed read is not the whole');
    });

    test('holds a place past the end of its line to that line', () async {
      write('/work/notes.txt', 'ab\ncd');

      final page = await files.readLines(
        'notes.txt',
        at: const LinePlace(line: 0, into: 99),
      );

      expect(page.start, const LinePlace(line: 0, into: 2));
      expect(page.text, '\ncd');
    });

    test('keeps nothing beyond the last line', () async {
      write('/work/notes.txt', 'a\nb');

      final page = await files.readLines(
        'notes.txt',
        at: const LinePlace(line: 9),
      );

      expect(page.text, isEmpty);
      expect(page.remaining, 0);
      expect(page.extent.tally, 2);
    });

    test('an empty file is a whole excerpt of nothing', () async {
      write('/work/notes.txt', '');

      final page = await files.readLines('notes.txt');

      expect(page.text, isEmpty);
      expect(page.extent.isOrigin, isTrue);
      expect(page.isWhole, isTrue);
    });

    test('a limit of zero holds its place without taking anything', () async {
      write('/work/notes.txt', 'a\nb');

      final page = await files.readLines(
        'notes.txt',
        at: const LinePlace(line: 1),
        limit: 0,
      );

      expect(page.text, isEmpty);
      expect(page.next, const LinePlace(line: 1));
    });

    test('normalizes line endings', () async {
      write('/work/notes.txt', 'a\r\nb\rc');

      final page = await files.readLines('notes.txt');

      expect(page.text, 'a\nb\nc');
      expect(page.extent.tally, 3);
    });

    test('holds no more than the characters asked for', () async {
      write('/work/notes.txt', 'abcdef\ng');

      final page = await files.readLines('notes.txt', chars: 4);

      expect(page.text, 'abcd');
      expect(page.next, const LinePlace(line: 0, into: 4));
      expect(page.remaining, 2);
    });

    test('a character cap never splits a surrogate pair', () async {
      write('/work/notes.txt', 'a𝄞b');

      final page = await files.readLines('notes.txt', chars: 2);

      expect(page.text, 'a');
      expect(page.next, const LinePlace(line: 0, into: 1));
    });

    test('a cap and a limit each bind, whichever is met first', () async {
      write('/work/notes.txt', 'ab\ncd\nef');

      final byLines = await files.readLines('notes.txt', limit: 1, chars: 99);
      final byChars = await files.readLines('notes.txt', limit: 9, chars: 4);

      expect(byLines.text, 'ab\n');
      expect(byChars.text, 'ab\nc');
    });

    test('pages by character cap through to the end, honestly', () async {
      final source = 'first\n\n${'x' * 500}\nlast one 𝄞 here\nno newline';
      write('/work/awkward.txt', source);

      for (final room in [3, 7, 16, 64, 499, 501]) {
        final read = StringBuffer();
        var at = LinePlace.start;
        var pages = 0;

        while (true) {
          final page = await files.readLines(
            'awkward.txt',
            at: at,
            chars: room,
          );
          read.write(page.text);
          if (page.remaining == 0) break;
          expect(page.text, isNotEmpty, reason: 'stalled at $at, room $room');
          at = page.next;
          expect(pages += 1, lessThan(1000), reason: 'circling at room $room');
        }

        expect(read.toString(), source, reason: 'room $room');
      }
    });

    test('pages a file through to its end without gap or overlap', () async {
      // Every awkwardness at once: a line far longer than any window, empty
      // lines, a character held as a surrogate pair, and no ending newline.
      final source = 'first\n\n${'x' * 500}\nlast one 𝄞 here\nno newline';
      write('/work/awkward.txt', source);

      for (final room in [3, 7, 16, 64, 499, 501]) {
        final read = StringBuffer();
        var at = LinePlace.start;
        var pages = 0;

        while (true) {
          final page = (await files.readLines(
            'awkward.txt',
            at: at,
          )).within(room);
          read.write(page.text);
          if (page.remaining == 0) break;
          expect(page.text, isNotEmpty, reason: 'stalled at $at, room $room');
          at = page.next;
          expect(pages += 1, lessThan(1000), reason: 'circling at room $room');
        }

        // Pages carry their newlines, so the whole is only concatenation.
        expect(read.toString(), source, reason: 'room $room');
      }
    });

    test('writes nothing', () async {
      write('/work/notes.txt', 'a\nb');

      await files.readLines('notes.txt');

      expect(fileSystem.file('/work/notes.txt').readAsStringSync(), 'a\nb');
      expect(fileSystem.directory('/work').listSync(), hasLength(1));
    });
  });

  group('readBytes', () {
    test('reports the range it returned', () async {
      write('/work/notes.txt', 'abcdefgh');

      final page = await files.readBytes('notes.txt', offset: 2, length: 3);

      expect(page.text, 'cde');
      expect(page.start, const BytePlace(2));
      expect(page.next, const BytePlace(5));
      expect(page.extent, const BytePlace(8));
      expect(page.remaining, 3);
    });

    test('trims a window that ends mid-character', () async {
      fileSystem.file('/work/notes.txt').writeAsBytesSync(utf8.encode('ab€cd'));

      final page = await files.readBytes('notes.txt', length: 4);

      expect(page.text, 'ab');
      expect(page.next, const BytePlace(2));
    });

    test('starts on a boundary when the offset lands mid-character', () async {
      fileSystem.file('/work/notes.txt').writeAsBytesSync(utf8.encode('€ok'));

      final page = await files.readBytes('notes.txt', offset: 1, length: 100);

      expect(page.text, 'ok');
      expect(page.start, const BytePlace(3));
    });

    test('is empty past the end of the file', () async {
      write('/work/notes.txt', 'abc');

      final page = await files.readBytes('notes.txt', offset: 9, length: 100);

      expect(page.text, isEmpty);
      expect(page.remaining, 0);
    });

    test('moves past a fragment at the end of a truncated file', () async {
      // Bytes no fuller read can complete come back as replacements rather
      // than pinning a reader in place.
      fileSystem.file('/work/notes.txt').writeAsBytesSync([
        ...utf8.encode('ok'),
        0xE2,
        0x82,
      ]);

      final page = await files.readBytes('notes.txt', length: 100);
      expect(page.text, 'ok');
      expect(page.remaining, 2, reason: 'the fragment is honestly unread');

      final resumed = await files.readBytes(
        'notes.txt',
        offset: page.next.offset,
        length: 100,
      );
      expect(resumed.text, contains('\u{FFFD}'));
      expect(resumed.next.offset, greaterThan(page.next.offset));
    });

    test(
      'pages malformed bytes through without skipping or circling',
      () async {
        final junk = [
          ...utf8.encode('good '),
          0xFF,
          0x80,
          0x80,
          ...utf8.encode(' more€'),
          0xE2,
          0x82,
        ];
        fileSystem.file('/work/junk.bin').writeAsBytesSync(junk);

        var at = 0;
        var pages = 0;
        while (true) {
          final page = await files.readBytes('junk.bin', offset: at, length: 4);
          expect(
            page.next.offset,
            lessThanOrEqualTo(junk.length),
            reason: 'sent past the end from $at',
          );
          if (page.text.isNotEmpty) {
            expect(
              page.next.offset,
              greaterThan(at),
              reason: 'standing still at $at',
            );
          }
          at = page.next.offset;
          expect(pages += 1, lessThan(100), reason: 'circling at $at');
          if (page.remaining == 0) break;
        }
        expect(at, junk.length);
      },
    );

    test('is empty for no length at all', () async {
      write('/work/notes.txt', 'abc');

      final page = await files.readBytes('notes.txt', length: 0);

      expect(page.text, isEmpty);
      expect(page.start, BytePlace.start);
      expect(page.extent, const BytePlace(3));
    });
  });

  group('storeLines', () {
    test('writes every line and creates missing parents', () async {
      final stored = await files.storeLines(
        'out/tools/call-1',
        Stream.fromIterable(['one', 'two', 'three']),
      );

      expect(
        fileSystem.file('/work/out/tools/call-1').readAsStringSync(),
        'one\ntwo\nthree',
      );
      expect(stored.storedAt, '/work/out/tools/call-1');
    });

    test('answers with the whole of it when it fits', () async {
      final stored = await files.storeLines(
        'out/call-1',
        Stream.fromIterable(['one', 'two']),
      );

      expect(stored.head.text, 'one\ntwo');
      expect(stored.head.isWhole, isTrue);
      expect(stored.totalChars, 7);
      expect(stored.totalLines, 2);
    });

    test('bounds the head while writing all of it', () async {
      final stored = await keeping(9).storeLines(
        'out/call-1',
        Stream.fromIterable(['aaaa', 'bbbb', 'cccc']),
      );

      expect(stored.head.text, 'aaaa\nbbbb');
      expect(stored.head.next, const LinePlace(line: 1, into: 4));
      expect(stored.head.isWhole, isFalse);
      expect(stored.head.remaining, 2);
      expect(stored.totalChars, 14);
      expect(stored.totalLines, 3);
      expect(
        fileSystem.file('/work/out/call-1').readAsStringSync(),
        'aaaa\nbbbb\ncccc',
      );
    });

    test('keeps what it can of a line too long to hold', () async {
      final stored = await keeping(4).storeLines(
        'out/call-1',
        Stream.fromIterable(['aaaaaaaa', 'b']),
      );

      expect(stored.head.text, 'aaaa');
      expect(stored.head.next, const LinePlace(line: 0, into: 4));
      expect(stored.totalLines, 2);
    });

    test('writes an empty file for an empty stream', () async {
      final stored = await files.storeLines(
        'out/call-1',
        const Stream<String>.empty(),
      );

      expect(fileSystem.file('/work/out/call-1').readAsStringSync(), isEmpty);
      expect(stored.totalLines, 0);
      expect(stored.head.isWhole, isTrue);
    });

    test('places its head where readLines will land', () async {
      // The head is a page of the stored file, so the place it stops at has
      // to be one the file reads back from.
      final stored = await keeping(9).storeLines(
        'out/call-1',
        Stream.fromIterable(['abcdef', 'gh', 'i']),
      );

      final resumed = await files.readLines(
        stored.storedAt,
        at: stored.head.next,
      );

      expect(stored.head.text + resumed.text, 'abcdef\ngh\ni');
    });
  });

  group('openRecordFile', () {
    test('records to a path, creating missing parents', () async {
      final recording = await files.openRecordFile('out/tools/call-1')
        ..append(_bytes('one'), _bytes('pen'))
        ..append(_bytes('two'), Uint8List(0));
      await recording.close();

      expect(recording.path, '/work/out/tools/call-1');
      expect(recording.records, 2);
    });
  });

  group('openRecords', () {
    test('reads back a recording written at the same path', () async {
      await (await files.openRecordFile('out/call-1')
            ..append(_bytes('one'), Uint8List(0)))
          .close();

      final records = await (await files.openRecords('out/call-1'))!.read(0, 5);

      expect(records.single.body, _bytes('one'));
    });

    test('is null when nothing is there', () async {
      expect(await files.openRecords('out/missing'), isNull);
    });

    test('is null for a directory', () async {
      fileSystem.directory('/work/out').createSync(recursive: true);

      expect(await files.openRecords('out'), isNull);
    });

    test('holds no records for a file that is not a recording', () async {
      write('/work/out/call-1', 'plain text, not a recording at all');

      expect((await files.openRecords('out/call-1'))!.records, 0);
    });
  });

  group('storeProse', () {
    test('writes the whole text and heads it', () async {
      final stored = await keeping(10).storeProse('out/call-1', 'x' * 50);

      expect(stored.head.text, 'x' * 10);
      expect(stored.head.isWhole, isFalse);
      expect(stored.totalChars, 50);
      expect(
        fileSystem.file('/work/out/call-1').readAsStringSync().length,
        50,
      );
    });

    test('answers with the whole of short text', () async {
      final stored = await files.storeProse('out/call-1', 'ab\ncd');

      expect(stored.head.text, 'ab\ncd');
      expect(stored.head.isWhole, isTrue);
      expect(stored.totalLines, 2);
    });

    test('does not split a surrogate pair', () async {
      final stored = await keeping(3).storeProse('out/call-1', 'ab𝄞cd');

      expect(stored.head.text, 'ab');
    });

    test('normalizes line endings so its places hold on read back', () async {
      final stored = await files.storeProse('out/call-1', 'ab\r\ncd');

      expect(fileSystem.file('/work/out/call-1').readAsStringSync(), 'ab\ncd');
      expect(stored.totalChars, 5);
      expect(stored.totalLines, 2);
    });
  });

  group('readableLines', () {
    test('yields the lines of a readable file', () async {
      write('/work/notes.txt', 'one\ntwo');

      expect(await files.readableLines('notes.txt').toList(), ['one', 'two']);
    });

    test('yields nothing for a file that cannot be read', () async {
      expect(await files.readableLines('missing.txt').toList(), isEmpty);
    });
  });

  group('children', () {
    test('names each child and sizes the files', () async {
      write('/work/src/a.dart', 'hello');
      fileSystem.directory('/work/src/nested').createSync();

      final entries = await files.children('src').toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      expect(entries.map((e) => e.name), ['a.dart', 'nested']);
      expect(entries.first.kind, FileKind.file);
      expect(entries.first.size, 5);
      expect(entries.first.path, '/work/src/a.dart');
      expect(entries.last.kind, FileKind.directory);
      expect(entries.last.size, 0);
    });

    test('does not descend on its own', () async {
      write('/work/src/nested/deep.dart', 'x');

      final entries = await files.children('src').toList();

      expect(entries.map((e) => e.name), ['nested']);
    });

    test('yields nothing for a directory that is not there', () async {
      expect(await files.children('missing').toList(), isEmpty);
    });

    test('names a link as a link, not as what it points at', () async {
      // A caller walking a tree has to be able to tell, or it will follow one
      // back into somewhere it has already been.
      write('/work/src/a.dart', 'hello');
      fileSystem.link('/work/src/shortcut').createSync('/work/src/a.dart');

      final entries = await files.children('src').toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      expect(entries.map((e) => e.name), ['a.dart', 'shortcut']);
      expect(entries.last.kind, FileKind.link);
      expect(entries.last.size, 0, reason: 'the link itself holds nothing');
    });
  });

  group('pathOf', () {
    test('spells a relative path absolutely, present or not', () {
      expect(files.pathOf('notes.txt'), '/work/notes.txt');
      expect(files.pathOf('nested/../notes.txt'), '/work/notes.txt');
    });

    test('leaves an absolute path alone', () {
      expect(files.pathOf('/elsewhere/notes.txt'), '/elsewhere/notes.txt');
    });
  });
}
