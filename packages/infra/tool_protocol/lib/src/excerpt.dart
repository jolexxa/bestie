import 'dart:convert';
import 'dart:math' as math;

import 'package:meta/meta.dart';

/// Which end of an excerpt gives way when there is not room for all of it.
enum Anchor { leading, trailing }

/// A place in a body of text, in the unit the body is paged by.
@immutable
sealed class TextPlace<P extends TextPlace<P>> {
  const TextPlace();

  /// Where a reader lands after reading [text] from here.
  P advanced(String text);

  /// Units unread between here and [extent], a partly read one counting.
  int remainingTo(P extent);

  /// Whether this is the very beginning.
  bool get isOrigin;
}

/// Where a reader sits in line-paged text: which line, and how far into it.
final class LinePlace extends TextPlace<LinePlace> {
  const LinePlace({required this.line, this.into = 0});

  static const LinePlace start = LinePlace(line: 0);

  /// Line holding the character, counted from zero.
  final int line;

  /// UTF-16 units into [line], zero at its start.
  final int into;

  /// Lines any part of which lies before this place.
  int get tally => line + (into > 0 ? 1 : 0);

  @override
  LinePlace advanced(String text) {
    final broke = text.lastIndexOf('\n');
    return broke < 0
        ? LinePlace(line: line, into: into + text.length)
        : LinePlace(
            line: line + '\n'.allMatches(text).length,
            into: text.length - broke - 1,
          );
  }

  @override
  int remainingTo(LinePlace extent) {
    if (line > extent.line) return 0;
    if (line == extent.line) return into < extent.into ? 1 : 0;
    return extent.tally - line;
  }

  @override
  bool get isOrigin => line == 0 && into == 0;

  @override
  bool operator ==(Object other) =>
      other is LinePlace && other.line == line && other.into == into;

  @override
  int get hashCode => Object.hash(line, into);

  @override
  String toString() => 'LinePlace(line: $line, into: $into)';
}

/// Where a reader sits in character-paged text.
final class CharPlace extends TextPlace<CharPlace> {
  const CharPlace(this.offset);

  static const CharPlace start = CharPlace(0);

  /// UTF-16 units before this place.
  final int offset;

  @override
  CharPlace advanced(String text) => CharPlace(offset + text.length);

  @override
  int remainingTo(CharPlace extent) => math.max(0, extent.offset - offset);

  @override
  bool get isOrigin => offset == 0;

  @override
  bool operator ==(Object other) =>
      other is CharPlace && other.offset == offset;

  @override
  int get hashCode => offset.hashCode;

  @override
  String toString() => 'CharPlace($offset)';
}

/// Where a reader sits in byte-paged text.
///
/// A replacement character measures as the one byte it at least stood for,
/// so a reader lands at or before what they were shown — never past it.
final class BytePlace extends TextPlace<BytePlace> {
  const BytePlace(this.offset);

  static const BytePlace start = BytePlace(0);

  /// Bytes before this place.
  final int offset;

  @override
  BytePlace advanced(String text) => BytePlace(
    offset + utf8.encode(text).length - 2 * '\u{FFFD}'.allMatches(text).length,
  );

  @override
  int remainingTo(BytePlace extent) => math.max(0, extent.offset - offset);

  @override
  bool get isOrigin => offset == 0;

  @override
  bool operator ==(Object other) =>
      other is BytePlace && other.offset == offset;

  @override
  int get hashCode => offset.hashCode;

  @override
  String toString() => 'BytePlace($offset)';
}

/// Text taken from a larger whole: what was taken, where it begins, and where
/// the whole of it ends.
final class Excerpt<P extends TextPlace<P>> {
  const Excerpt({
    required this.text,
    required this.start,
    required this.extent,
    this.anchor = Anchor.leading,
  });

  /// The text taken.
  final String text;

  /// Where [text] begins in the whole.
  final P start;

  /// Where the whole ends.
  final P extent;

  /// Which end of [text] gives way under [within].
  final Anchor anchor;

  /// Where a reader lands after this, which is where they pick up.
  P get next => start.advanced(text);

  /// Units the whole holds beyond this excerpt.
  int get remaining => next.remainingTo(extent);

  /// Whether this excerpt is the whole of it.
  bool get isWhole => start.isOrigin && remaining == 0;

  /// This excerpt, holding no more of its text than [room] allows; a
  /// trailing cut moves [start] with it, so [next] stays honest.
  Excerpt<P> within(int room) {
    if (text.length <= room) return this;
    if (anchor == Anchor.leading) {
      return Excerpt(
        text: clip(text, room),
        start: start,
        extent: extent,
        anchor: anchor,
      );
    }
    final kept = clipEnd(text, room);
    return Excerpt(
      text: kept,
      start: start.advanced(text.substring(0, text.length - kept.length)),
      extent: extent,
      anchor: anchor,
    );
  }

  /// The answer [tell] makes of this, held to [maxChars]: where it runs
  /// long, the text gives way by the overflow and it is told again.
  String told(int maxChars, String Function(Excerpt<P> shown) tell) {
    var shown = this;
    var answer = tell(shown);
    // The text strictly shrinks each pass, so this cannot circle.
    while (answer.length > maxChars && shown.text.length > 1) {
      shown = shown.within(
        math.max(0, shown.text.length - (answer.length - maxChars)),
      );
      answer = tell(shown);
    }
    return answer;
  }

  /// An excerpt of line-paged text.
  static Excerpt<LinePlace> lines(
    String text, {
    required LinePlace extent,
    LinePlace at = LinePlace.start,
    Anchor anchor = Anchor.leading,
  }) => Excerpt(text: text, start: at, extent: extent, anchor: anchor);

  /// An excerpt of character-paged text.
  static Excerpt<CharPlace> chars(
    String text, {
    required int total,
    int start = 0,
    Anchor anchor = Anchor.leading,
  }) => Excerpt(
    text: text,
    start: CharPlace(start),
    extent: CharPlace(total),
    anchor: anchor,
  );

  /// An excerpt of byte-paged text.
  static Excerpt<BytePlace> bytes(
    String text, {
    required int total,
    int start = 0,
    Anchor anchor = Anchor.leading,
  }) => Excerpt(
    text: text,
    start: BytePlace(start),
    extent: BytePlace(total),
    anchor: anchor,
  );

  /// [text] cut to [maxChars] without splitting a surrogate pair.
  static String clip(String text, int maxChars) {
    if (maxChars <= 0) return '';
    if (text.length <= maxChars) return text;
    final lastKept = text.codeUnitAt(maxChars - 1);
    final splitsPair = lastKept >= 0xD800 && lastKept <= 0xDBFF;
    return text.substring(0, splitsPair ? maxChars - 1 : maxChars);
  }

  /// The last [maxChars] of [text], without splitting a surrogate pair.
  static String clipEnd(String text, int maxChars) {
    if (maxChars <= 0) return '';
    if (text.length <= maxChars) return text;
    final from = text.length - maxChars;
    final firstKept = text.codeUnitAt(from);
    final splitsPair = firstKept >= 0xDC00 && firstKept <= 0xDFFF;
    return text.substring(splitsPair ? from + 1 : from);
  }
}
