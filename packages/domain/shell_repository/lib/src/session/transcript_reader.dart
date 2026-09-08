import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:byte_codec/byte_codec.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:shell_repository/src/session/transcript_page.dart';
import 'package:shell_repository/src/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart';

/// A recording read as one run of characters.
@PartOf(ShellRepository)
abstract base class TranscriptReader {
  /// Where the recording is.
  String get path;

  /// Lines it holds.
  int get lines;

  /// UTF-16 code units it holds.
  int get chars;

  /// Whether something is still writing to this.
  bool get isLive => false;

  /// Where the [at]th character sits.
  Future<RecordCursor> locate(int at);

  /// [count] lines from [from], in order, as the bytes they were kept as.
  Future<List<ByteRecord>> records(int from, int count);

  /// Lets go of whatever was opened to read. A no-op for a recording whose
  /// writer is still holding it.
  Future<void> dispose() async {}

  /// The characters from [at], as many as [length] holds.
  Future<TranscriptPage> window({required int at, required int length}) async {
    final total = chars;
    final asked = at.clamp(0, total);
    if (length <= 0 || asked >= total) {
      return TranscriptPage.empty(
        at: asked,
        totalChars: total,
        totalLines: lines,
        isLive: isLive,
      );
    }

    final to = math.min(total, asked + length);
    final start = await locate(asked);
    final end = await locate(to);
    final joined = _join(
      await records(start.record, end.record - start.record + 1),
    );

    // A page never begins mid-character, so a window landing on the far
    // half of a pair starts after it.
    var into = start.into.clamp(0, joined.length);
    var from = asked;
    if (_splitsPair(joined, into)) {
      into += 1;
      from += 1;
    }

    final room = joined.length - into;
    // Never none of it while there is any of it, so a reader carrying on from
    // where the last page stopped cannot be handed a page that stands still.
    var take = math.min(math.max(to - from, 1), room);
    // A pair split down the middle is half a character in each page, so the
    // cut comes back to the last place a character actually ended.
    if (take > 1 && take < room && _splitsPair(joined, into + take)) take -= 1;

    return TranscriptPage(
      body: Excerpt.chars(
        joined.substring(into, into + take),
        start: from,
        total: total,
      ),
      totalLines: lines,
      isLive: isLive,
    );
  }

  /// As much of the end as [length] holds — the same window read from the
  /// other side, anchored there so it is its end that survives any cut.
  Future<TranscriptPage> ending({required int length}) async {
    final page = await window(
      at: math.max(0, chars - length),
      length: length,
    );
    return TranscriptPage(
      body: Excerpt.chars(
        page.body.text,
        start: page.body.start.offset,
        total: page.body.extent.offset,
        anchor: Anchor.trailing,
      ),
      totalLines: page.totalLines,
      isLive: page.isLive,
    );
  }

  /// The bytes that draw [limit] lines from [offset] on a terminal — terminal
  /// input, for the same parser that drew the output in the first place.
  Future<Uint8List> ansi({int offset = 0, int? limit}) async {
    final page = await records(offset.clamp(0, lines), limit ?? lines);
    final out = ByteWriter(1 << 12);
    for (final record in page) {
      if (out.isNotEmpty) {
        out
          ..byte(0x0D)
          ..byte(0x0A);
      }
      penToAnsi(record.body, record.note, out);
    }
    return out.take();
  }

  String _join(List<ByteRecord> page) {
    final text = StringBuffer();
    for (final record in page) {
      text
        ..write(utf8.decode(record.body, allowMalformed: true))
        ..write('\n');
    }
    return text.toString();
  }

  bool _splitsPair(String text, int at) =>
      at > 0 &&
      at < text.length &&
      _isHigh(text.codeUnitAt(at - 1)) &&
      _isLow(text.codeUnitAt(at));

  bool _isHigh(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  bool _isLow(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}

/// A recording nobody is writing to any more.
@PartOf(ShellRepository)
final class StoredTranscript extends TranscriptReader {
  StoredTranscript(this._record);

  final RecordFile _record;

  @override
  String get path => _record.path;

  @override
  int get lines => _record.records;

  @override
  int get chars => _record.chars;

  @override
  Future<RecordCursor> locate(int at) => _record.locate(at);

  @override
  Future<List<ByteRecord>> records(int from, int count) =>
      _record.read(from, count);

  @override
  Future<void> dispose() => _record.close();
}

/// Nothing recorded, at a path that holds no recording, so a call that wrote
/// no output costs every caller a read rather than a null check.
@PartOf(ShellRepository)
final class EmptyTranscript extends TranscriptReader {
  EmptyTranscript(this.path);

  @override
  final String path;

  @override
  int get lines => 0;

  @override
  int get chars => 0;

  @override
  Future<RecordCursor> locate(int at) async => RecordCursor.start;

  @override
  Future<List<ByteRecord>> records(int from, int count) async => const [];
}
