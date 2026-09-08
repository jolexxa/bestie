/// An append-only file of little-endian records with absolute offsets,
/// holding the offset of every `stride`-th frame in an index at the tail —
/// the one place a structure whose size is unknown until the end can go in a
/// file being appended to and read from at once — and `footerSize` last, so
/// the footer finds itself.
///
/// Every frame declares what it weighs and every index entry carries the
/// weight before it, which is what lets a place in the recording be found by
/// searching rather than by reading it up to there.
///
/// ```text
/// [header 8B]
/// [frame][frame][frame] …      appended as they arrive
/// [index]                      written once, at finish()
/// [footer 40B]
///
/// frame  := varint bodyLen | varint noteLen | varint units | body | note
/// header := magic[6] | u16 version
/// index  := (u64 offset | u64 charsBefore) per stride
/// footer := magic[6] | u16 version | u16 stride | u16 reserved
///           | u64 records | u64 weight | u64 indexOffset | u32 footerSize
/// ```
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:byte_codec/byte_codec.dart';
import 'package:file/file.dart';
import 'package:files_data_source/src/models/byte_record.dart';
import 'package:files_data_source/src/models/record_cursor.dart';
import 'package:intentions/intentions.dart';

/// What a recording opens with: `"COW\0TR"`, the NUL making it read as binary
/// to anything sampling the first bytes for text.
const List<int> _magic = [0x43, 0x4F, 0x57, 0x00, 0x54, 0x52];

const int _version = 1;
const int _headerSize = 8;
const int _footerSize = 40;

/// Bytes an index entry takes: where a block starts, and what came before it.
const int _entrySize = 16;

/// Frames between index entries: a byte of index per eight lines.
const int _defaultStride = 64;

/// Buffered bytes that bring on a write.
const int _drainAt = 1 << 16;

/// Bytes a forward reader pulls at a time.
const int _chunkSize = 1 << 16;

final Uint8List _nothing = Uint8List(0);

/// What sat at the end of a file opened to read.
enum _Tail {
  /// A footer this version wrote, and the index it points at.
  read,

  /// A footer of a version this one does not know, which is a recording to
  /// leave alone rather than a recording to repair.
  foreign,

  /// No footer at all — the writer never got to one.
  missing,
}

/// A file of records being appended to, read from, or both, through one
/// handle and a buffer of its own — [RandomAccessFile.writeFrom] copies before
/// it returns, which is what makes handing it a reused buffer safe.
@model
final class RecordFile {
  RecordFile._(this._handle, this.path, {required bool finished})
    : _finished = finished;

  /// Starts a recording at [file], replacing whatever was there.
  static Future<RecordFile> create(File file) async {
    final handle = await file.open(mode: FileMode.write);
    return RecordFile._(handle, file.absolute.path, finished: false).._header();
  }

  /// Opens the recording at [file] to read, rebuilding the index by scanning
  /// when its writer died before [finish] could leave one.
  static Future<RecordFile> open(File file) async {
    final handle = await file.open();
    final record = RecordFile._(handle, file.absolute.path, finished: true);
    await record._load();
    return record;
  }

  /// Where the records are.
  final String path;

  final RandomAccessFile _handle;
  final ByteWriter _buffer = ByteWriter(1 << 12);
  final List<int> _offsets = [];

  /// Characters before the first record of each block, so [locate] searches
  /// the index and reads only the block it lands in.
  final List<int> _marks = [];

  /// Ordering for everything that touches the handle, in both directions.
  Future<void> _pending = Future<void>.value();
  Future<void> _lastWrite = Future<void>.value();

  int _stride = _defaultStride;
  int _flushed = 0;
  int _records = 0;
  int _weight = 0;
  bool _finished;

  /// Records written so far.
  int get records => _records;

  /// The sum of what callers declared each record weighs, whatever they
  /// measured.
  int get weight => _weight;

  /// What the records occupy read as one run, in whatever their writer
  /// measured them in, each of them owning the separator behind it.
  int get chars => _weight + _records;

  /// Whether the footer has been written.
  bool get isFinished => _finished;

  /// Where the next frame will start.
  int get _offset => _flushed + _buffer.length;

  /// Appends a record of [body] and [note], said to weigh [weight], for the
  /// cost of a buffer append and no more — and a no-op once [finish] has run.
  void append(Uint8List body, Uint8List note, {int weight = 0}) {
    if (_finished) return;
    if (_records % _stride == 0) {
      _offsets.add(_offset);
      _marks.add(chars);
    }
    _buffer
      ..varint(body.length)
      ..varint(note.length)
      ..varint(weight)
      ..bytes(body)
      ..bytes(note);
    _records += 1;
    _weight += weight;
    if (_buffer.length >= _drainAt) _drain();
  }

  /// Pushes buffered records out, so a reader sees everything [append] took.
  Future<void> flush() {
    _drain();
    return _lastWrite;
  }

  /// At most [limit] records starting at [from], flushing first, so the
  /// in-memory index serves a recording in progress as it does a closed one.
  Future<List<ByteRecord>> read(int from, int limit) {
    if (limit <= 0 || from < 0 || from >= _records) {
      return Future.value(const []);
    }
    final count = math.min(limit, _records - from);
    _drain();
    return _queue(() => _readFrom(from, count));
  }

  /// Where the [at]th character of the recording read as one run sits, past
  /// the end being the ordinal after the last record.
  Future<RecordCursor> locate(int at) {
    if (at <= 0 || _records == 0) {
      return Future.value(RecordCursor.start);
    }
    if (at >= chars) return Future.value(RecordCursor(_records, 0));
    _drain();
    return _queue(() => _seek(at));
  }

  Future<RecordCursor> _seek(int at) async {
    var block = 0;
    var high = _marks.length - 1;
    while (block < high) {
      final mid = (block + high + 1) >> 1;
      if (_marks[mid] <= at) {
        block = mid;
      } else {
        high = mid - 1;
      }
    }

    var record = block * _stride;
    var before = _marks[block];
    final forward = _Forward(_handle, _offsets[block]);
    while (record < _records) {
      final units = await forward.skip();
      if (units == null) break;
      if (before + units + 1 > at) break;
      before += units + 1;
      record += 1;
    }
    return RecordCursor(record, at - before);
  }

  /// Writes the index and the footer and stops taking records.
  Future<void> finish() async {
    if (_finished) return;
    _finished = true;
    await _seal();
  }

  /// Finishes if it has not already, and lets the handle go.
  Future<void> close() async {
    await finish();
    await _queue(_handle.close);
  }

  void _header() => _buffer
    ..bytes(_magic)
    ..uint16(_version);

  Future<void> _seal() async {
    final indexOffset = _offset;
    for (var block = 0; block < _offsets.length; block++) {
      _buffer
        ..uint64(_offsets[block])
        ..uint64(_marks[block]);
    }
    _buffer
      ..bytes(_magic)
      ..uint16(_version)
      ..uint16(_stride)
      ..uint16(0)
      ..uint64(_records)
      ..uint64(_weight)
      ..uint64(indexOffset)
      ..uint32(_footerSize);
    await flush();
  }

  void _drain() {
    if (_buffer.isEmpty) return;
    final bytes = _buffer.take();
    final at = _flushed;
    _buffer.reset();
    _flushed += bytes.length;
    _lastWrite = _queue(() async {
      await _handle.setPosition(at);
      await _handle.writeFrom(bytes);
    });
  }

  /// Runs [action] after everything already asked for, so reads and writes
  /// never fight over the handle's position.
  Future<T> _queue<T>(Future<T> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  Future<List<ByteRecord>> _readFrom(int from, int count) async {
    final block = from ~/ _stride;
    final forward = _Forward(_handle, _offsets[block]);
    for (var skip = from - block * _stride; skip > 0; skip--) {
      if (await forward.skip() == null) return const [];
    }
    final records = <ByteRecord>[];
    for (var taken = 0; taken < count; taken++) {
      final record = await forward.record();
      if (record == null) break;
      records.add(record);
    }
    return records;
  }

  Future<void> _load() async {
    final length = await _handle.length();
    _flushed = length;
    switch (await _footer(length)) {
      case _Tail.read:
        return;
      case _Tail.foreign:
        return;
      case _Tail.missing:
        await _rebuild(length);
    }
  }

  /// Reads the index out of a footer, saying what it found there.
  Future<_Tail> _footer(int length) async {
    if (length < _headerSize + _footerSize) return _Tail.missing;
    final tail = await _at(length - 4, 4);
    if (tail.length < 4) return _Tail.missing;
    final size = ByteReader(tail).uint32();
    if (size < _footerSize || size > length - _headerSize) return _Tail.missing;

    final bytes = await _at(length - size, _footerSize);
    if (bytes.length < _footerSize) return _Tail.missing;
    final reader = ByteReader(bytes);
    if (!_isMagic(reader.bytes(_magic.length))) return _Tail.missing;
    if (reader.uint16() != _version) return _Tail.foreign;

    final stride = reader.uint16();
    reader.skip(2);
    final records = reader.uint64();
    final weight = reader.uint64();
    final indexOffset = reader.uint64();
    if (stride < 1 || indexOffset < _headerSize) return _Tail.missing;

    final blocks = (records + stride - 1) ~/ stride;
    final indexSize = blocks * _entrySize;
    if (indexOffset + indexSize > length - size) return _Tail.missing;
    final index = await _at(indexOffset, indexSize);
    if (index.length < indexSize) return _Tail.missing;

    final entries = ByteReader(index);
    _offsets.clear();
    _marks.clear();
    for (var block = 0; block < blocks; block++) {
      _offsets.add(entries.uint64());
      _marks.add(entries.uint64());
    }
    _stride = stride;
    _records = records;
    _weight = weight;
    return _Tail.read;
  }

  /// Rebuilds the index of a recording that never got a footer, by walking it
  /// — measures and all, since every frame carries its own.
  Future<void> _rebuild(int length) async {
    _offsets.clear();
    _marks.clear();
    _records = 0;
    _weight = 0;
    _stride = _defaultStride;

    if (!_isMagic(await _at(0, _magic.length))) return;

    final forward = _Forward(_handle, _headerSize);
    while (forward.offset < length) {
      final at = forward.offset;
      final units = await forward.skip();
      // Stepping over a frame does not read it, so a file ending inside one
      // shows up as having stepped past the end rather than as a short read.
      if (units == null || forward.offset > length) break;
      if (_records % _stride == 0) {
        _offsets.add(at);
        _marks.add(chars);
      }
      _records += 1;
      _weight += units;
    }
  }

  Future<Uint8List> _at(int offset, int count) => _queue(() async {
    await _handle.setPosition(offset);
    final bytes = Uint8List(count);
    return Uint8List.sublistView(bytes, 0, await _handle.readInto(bytes));
  });

  bool _isMagic(Uint8List bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }
}

/// A forward-only reader over a stretch of a file, pulling it a chunk at a
/// time so decoding a page of frames is a handful of reads rather than one per
/// field.
final class _Forward {
  _Forward(this._handle, int at) : _next = at;

  final RandomAccessFile _handle;

  Uint8List _bytes = _nothing;
  int _cursor = 0;

  /// Where the byte after the loaded ones sits in the file.
  int _next;

  /// Where the next byte to be decoded sits in the file.
  int get offset => _next - (_bytes.length - _cursor);

  /// The record at [offset], or null if the file ends inside it — which is
  /// what a killed writer leaves behind, so it is a signal, not a failure.
  Future<ByteRecord?> record() async {
    final bodyLength = await _varint();
    if (bodyLength == null) return null;
    final noteLength = await _varint();
    if (noteLength == null) return null;
    final units = await _varint();
    if (units == null) return null;
    final body = await _take(bodyLength);
    if (body == null) return null;
    final note = await _take(noteLength);
    if (note == null) return null;
    return ByteRecord(body: body, note: note, units: units);
  }

  /// Steps over the record at [offset] without copying it.
  Future<int?> skip() async {
    final bodyLength = await _varint();
    if (bodyLength == null) return null;
    final noteLength = await _varint();
    if (noteLength == null) return null;
    final units = await _varint();
    if (units == null) return null;
    _advance(bodyLength + noteLength);
    return units;
  }

  Future<int?> _varint() async {
    var value = 0;
    var shift = 0;
    while (shift < 64) {
      if (!await _ensure(1)) return null;
      final byte = _bytes[_cursor++];
      value |= (byte & 0x7F) << shift;
      if (byte & 0x80 == 0) return value;
      shift += 7;
    }
    return null;
  }

  Future<Uint8List?> _take(int count) async {
    if (count == 0) return _nothing;
    if (!await _ensure(count)) return null;
    final taken = Uint8List.fromList(
      Uint8List.sublistView(_bytes, _cursor, _cursor + count),
    );
    _cursor += count;
    return taken;
  }

  void _advance(int count) {
    final loaded = _bytes.length - _cursor;
    if (loaded >= count) {
      _cursor += count;
      return;
    }
    _next += count - loaded;
    _bytes = _nothing;
    _cursor = 0;
  }

  Future<bool> _ensure(int count) async {
    final loaded = _bytes.length - _cursor;
    if (loaded >= count) return true;

    final want = count > _chunkSize ? count : _chunkSize;
    final grown = Uint8List(loaded + want)
      ..setRange(0, loaded, _bytes, _cursor);
    await _handle.setPosition(_next);
    final read = await _handle.readInto(grown, loaded, loaded + want);
    _next += read;
    _bytes = Uint8List.sublistView(grown, 0, loaded + read);
    _cursor = 0;
    return _bytes.length >= count;
  }
}
