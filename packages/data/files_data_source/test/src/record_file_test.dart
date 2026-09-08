import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:test/test.dart';

Uint8List _bytes(String text) => Uint8List.fromList(text.codeUnits);

String _text(Uint8List bytes) => String.fromCharCodes(bytes);

/// Enough records to cross the index stride more than once.
const int _crossesStride = 200;

/// Where the version sits in the footer, for a test that has to spoil it.
const int _footerSize = 40;
const int _magicSize = 6;
const int _version = 1;

void main() {
  late FileSystem fileSystem;
  late File file;

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    file = fileSystem.file('/recording');
  });

  Future<RecordFile> written(
    int count, {
    Uint8List Function(int at)? note,
    bool finish = true,
  }) async {
    final recording = await RecordFile.create(file);
    for (var at = 0; at < count; at++) {
      recording.append(
        _bytes('line $at'),
        note?.call(at) ?? Uint8List(0),
        weight: at,
      );
    }
    if (finish) await recording.finish();
    return recording;
  }

  group('round trip', () {
    test('reads back every record it was given', () async {
      await (await written(_crossesStride)).close();

      final stored = await RecordFile.open(file);
      final records = await stored.read(0, _crossesStride);

      expect(records, hasLength(_crossesStride));
      expect(_text(records.first.body), 'line 0');
      expect(_text(records.last.body), 'line ${_crossesStride - 1}');
    });

    test('keeps both fields apart', () async {
      await (await written(3, note: (at) => _bytes('pen $at'))).close();

      final records = await (await RecordFile.open(file)).read(0, 3);

      expect(records.map((r) => _text(r.body)), ['line 0', 'line 1', 'line 2']);
      expect(records.map((r) => _text(r.note)), ['pen 0', 'pen 1', 'pen 2']);
    });

    test('carries a record with no note', () async {
      await (await written(1)).close();

      final records = await (await RecordFile.open(file)).read(0, 1);

      expect(records.single.note, isEmpty);
    });

    test('carries a record larger than a read chunk', () async {
      final big = Uint8List(1 << 17)..fillRange(0, 1 << 17, 0x61);
      final recording = await RecordFile.create(file);
      recording
        ..append(big, Uint8List(0))
        ..append(_bytes('after'), Uint8List(0));
      await recording.close();

      final records = await (await RecordFile.open(file)).read(0, 2);

      expect(records.first.body, hasLength(1 << 17));
      expect(_text(records.last.body), 'after');
    });

    test('holds a recording with nothing in it', () async {
      await (await written(0)).close();

      final stored = await RecordFile.open(file);

      expect(stored.records, 0);
      expect(await stored.read(0, 10), isEmpty);
    });
  });

  group('seeking', () {
    test(
      'reaches a record past the first index block without reading it all',
      () async {
        await (await written(_crossesStride)).close();

        final records = await (await RecordFile.open(file)).read(130, 3);

        expect(records.map((r) => _text(r.body)), [
          'line 130',
          'line 131',
          'line 132',
        ]);
      },
    );

    test('lands exactly on an index entry', () async {
      await (await written(_crossesStride)).close();

      final records = await (await RecordFile.open(file)).read(128, 1);

      expect(_text(records.single.body), 'line 128');
    });

    test('stops at the end rather than at the limit', () async {
      await (await written(10)).close();

      final records = await (await RecordFile.open(file)).read(8, 100);

      expect(records.map((r) => _text(r.body)), ['line 8', 'line 9']);
    });

    test('answers with nothing when asked past the end', () async {
      await (await written(10)).close();

      expect(await (await RecordFile.open(file)).read(10, 5), isEmpty);
    });

    test('answers with nothing for a limit that asks for none', () async {
      await (await written(10)).close();

      expect(await (await RecordFile.open(file)).read(0, 0), isEmpty);
    });

    test('answers with nothing for an offset before the beginning', () async {
      await (await written(10)).close();

      expect(await (await RecordFile.open(file)).read(-1, 5), isEmpty);
    });
  });

  group('while still recording', () {
    test('reads what has been appended', () async {
      final recording = await written(_crossesStride, finish: false);

      final records = await recording.read(150, 2);

      expect(records.map((r) => _text(r.body)), ['line 150', 'line 151']);
    });

    test('reads a record that is still only in the buffer', () async {
      final recording = await RecordFile.create(file);
      recording.append(_bytes('fresh'), Uint8List(0));

      final records = await recording.read(0, 1);

      expect(_text(records.single.body), 'fresh');
    });

    test('keeps appending correctly after a read moved the handle', () async {
      final recording = await RecordFile.create(file);
      recording.append(_bytes('first'), Uint8List(0));
      await recording.read(0, 1);
      recording.append(_bytes('second'), Uint8List(0));
      await recording.close();

      final records = await (await RecordFile.open(file)).read(0, 2);

      expect(records.map((r) => _text(r.body)), ['first', 'second']);
    });

    test('counts records and their weight as they arrive', () async {
      final recording = await written(4, finish: false);

      expect(recording.records, 4);
      expect(recording.weight, 0 + 1 + 2 + 3);
    });
  });

  group('finishing', () {
    test('carries the counts across to a reader', () async {
      await (await written(10)).close();

      final stored = await RecordFile.open(file);

      expect(stored.records, 10);
      expect(stored.weight, 45);
    });

    test('turns away records once it is finished', () async {
      final recording = await written(2);

      recording.append(_bytes('too late'), Uint8List(0));

      expect(recording.records, 2);
    });

    test('is safe to ask for twice', () async {
      final recording = await written(2);
      final before = await file.length();

      await recording.finish();

      expect(await file.length(), before);
    });

    test('reports itself finished', () async {
      final recording = await written(1, finish: false);
      expect(recording.isFinished, isFalse);

      await recording.finish();

      expect(recording.isFinished, isTrue);
    });
  });

  group('locate', () {
    /// Where record [at] begins: the writer declared every record weighs its
    /// own ordinal, and each of them owns the separator behind it.
    int startOf(int at) =>
        [for (var i = 0; i < at; i++) i + 1].fold(0, (sum, span) => sum + span);

    test('answers the start of a recording with nothing in it', () async {
      final cursor = await (await written(0)).locate(0);

      expect(cursor.record, 0);
      expect(cursor.into, 0);
    });

    test('never answers before the start', () async {
      final cursor = await (await written(10)).locate(-5);

      expect(cursor.record, 0);
      expect(cursor.into, 0);
    });

    test('lands at the front of a record on its first character', () async {
      final cursor = await (await written(
        _crossesStride,
      )).locate(startOf(150));

      expect(cursor.record, 150);
      expect(cursor.into, 0);
    });

    test('lands inside the record a character belongs to', () async {
      final cursor = await (await written(
        _crossesStride,
      )).locate(startOf(150) + 3);

      expect(cursor.record, 150);
      expect(cursor.into, 3);
    });

    test('leaves the separator to the record that owns it', () async {
      // Record 150 weighs 150, so the separator behind it is the character
      // after its last, and belongs to it rather than to what follows.
      final cursor = await (await written(
        _crossesStride,
      )).locate(startOf(150) + 150);

      expect(cursor.record, 150);
      expect(cursor.into, 150);
    });

    test('answers past the last record for a character past the end', () async {
      final recording = await written(10);

      final cursor = await recording.locate(recording.chars);

      expect(cursor.record, 10);
      expect(cursor.into, 0);
    });

    test(
      'reads a recording in progress the way it reads a stored one',
      () async {
        final live = await written(_crossesStride, finish: false);
        await live.flush();
        final at = startOf(150) + 3;

        final live0 = await live.locate(at);
        await live.close();
        final stored = await (await RecordFile.open(file)).locate(at);

        expect(stored.record, live0.record);
        expect(stored.into, live0.into);
      },
    );
  });

  group('recovery', () {
    Future<void> tear(int bytes) async {
      final whole = await file.readAsBytes();
      await file.writeAsBytes(
        Uint8List.sublistView(whole, 0, whole.length - bytes),
      );
    }

    test('rebuilds a recording whose writer never finished', () async {
      final recording = await written(_crossesStride, finish: false);
      await recording.flush();

      final stored = await RecordFile.open(file);

      expect(stored.records, _crossesStride);
      expect(_text((await stored.read(150, 1)).single.body), 'line 150');
    });

    test('drops a frame the writer was cut off inside', () async {
      final recording = await written(10, finish: false);
      await recording.flush();
      await tear(3);

      final stored = await RecordFile.open(file);

      expect(stored.records, 9);
      expect(_text((await stored.read(8, 1)).single.body), 'line 8');
    });

    // The measure rides in the frame rather than only in the footer, so a
    // scan rebuilds it the same way it rebuilds the offsets.
    test('recovers the measure every frame carries', () async {
      final recording = await written(10, finish: false);
      await recording.flush();

      final stored = await RecordFile.open(file);

      final declared = [
        for (var at = 0; at < 10; at++) at,
      ].fold(0, (sum, weight) => sum + weight);
      expect(stored.weight, declared);
      expect(stored.chars, declared + 10);
    });

    // Reading is not repairing. Two panes can be reading the same torn
    // recording at once, and a recording can sit somewhere unwritable.
    test('leaves the file exactly as it found it', () async {
      final recording = await written(10, finish: false);
      await recording.flush();
      await tear(3);
      final before = await file.readAsBytes();

      await (await RecordFile.open(file)).close();

      expect(await file.readAsBytes(), before);
    });

    test('answers the same way however often it is read', () async {
      final recording = await written(10, finish: false);
      await recording.flush();
      await tear(3);

      final first = await RecordFile.open(file);
      final second = await RecordFile.open(file);

      expect(first.records, 9);
      expect(second.records, 9);
      expect(_text((await second.read(8, 1)).single.body), 'line 8');
    });

    // The version is in the footer so a reader can tell a recording it does
    // not understand from one that was cut short. Guessing at the first would
    // mean rewriting a whole file to a format it was not written in.
    test('leaves a recording of a version it does not know alone', () async {
      await (await written(10)).close();
      final whole = await file.readAsBytes();
      // The footer opens with the magic, then the version.
      whole.buffer.asByteData().setUint16(
        whole.length - _footerSize + _magicSize,
        _version + 1,
        Endian.little,
      );
      await file.writeAsBytes(whole);

      final stored = await RecordFile.open(file);

      expect(stored.records, 0, reason: 'nothing is read out of it');
      expect(await file.readAsBytes(), whole, reason: 'and nothing written');
    });

    test('reads nothing out of a file that is not a recording', () async {
      await file.writeAsString('just some text, at length, not a recording');

      final stored = await RecordFile.open(file);

      expect(stored.records, 0);
      expect(await stored.read(0, 5), isEmpty);
    });

    test('reads nothing out of an empty file', () async {
      await file.create();

      expect((await RecordFile.open(file)).records, 0);
    });
  });

  test('opens as binary to anything sampling for text', () async {
    await (await written(1)).close();

    expect(await file.readAsBytes(), contains(0));
    expect((await file.readAsBytes()).sublist(0, 6), [67, 79, 87, 0, 84, 82]);
  });

  test('names where the records are', () async {
    final recording = await written(0);

    expect(recording.path, file.absolute.path);
  });
}
