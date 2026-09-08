import 'dart:convert';

import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  group('LinePlace', () {
    test('advancing over text without a newline stays on the line', () {
      expect(
        LinePlace.start.advanced('abc'),
        const LinePlace(line: 0, into: 3),
      );
    });

    test('advancing over a trailing newline lands at the next line start', () {
      expect(LinePlace.start.advanced('abc\n'), const LinePlace(line: 1));
    });

    test('advancing counts every newline and measures past the last', () {
      expect(
        const LinePlace(line: 2, into: 4).advanced('ab\ncd\nef'),
        const LinePlace(line: 4, into: 2),
      );
    });

    test('advancing over nothing goes nowhere', () {
      const at = LinePlace(line: 3, into: 7);
      expect(at.advanced(''), at);
    });

    test('a line boundary has one spelling', () {
      final stopped = LinePlace.start.advanced('one\ntwo\n');
      final walked = LinePlace.start.advanced('one\n').advanced('two\n');
      expect(stopped, const LinePlace(line: 2));
      expect(walked, stopped);
    });

    test('tally counts a partly entered line', () {
      expect(const LinePlace(line: 3).tally, 3);
      expect(const LinePlace(line: 3, into: 1).tally, 4);
    });

    test('remainingTo is zero at the extent', () {
      const extent = LinePlace(line: 10, into: 7);
      expect(extent.remainingTo(extent), 0);
    });

    test('remainingTo counts the line it stopped inside', () {
      expect(
        const LinePlace(
          line: 3,
          into: 5,
        ).remainingTo(const LinePlace(line: 10, into: 7)),
        8,
      );
    });

    test('remainingTo counts a partly read last line', () {
      expect(
        const LinePlace(
          line: 10,
          into: 3,
        ).remainingTo(const LinePlace(line: 10, into: 7)),
        1,
      );
    });

    test('remainingTo on the last line with nothing left is zero', () {
      expect(
        const LinePlace(
          line: 10,
          into: 7,
        ).remainingTo(const LinePlace(line: 10, into: 7)),
        0,
      );
    });

    test('remainingTo never goes negative', () {
      expect(
        const LinePlace(line: 12).remainingTo(const LinePlace(line: 10)),
        0,
      );
    });

    test('origin is the start and only the start', () {
      expect(LinePlace.start.isOrigin, isTrue);
      expect(const LinePlace(line: 0, into: 1).isOrigin, isFalse);
      expect(const LinePlace(line: 1).isOrigin, isFalse);
    });
  });

  group('CharPlace', () {
    test('advances by code units', () {
      expect(const CharPlace(3).advanced('abcd'), const CharPlace(7));
    });

    test('remainingTo measures to the extent and clamps at zero', () {
      expect(const CharPlace(3).remainingTo(const CharPlace(10)), 7);
      expect(const CharPlace(12).remainingTo(const CharPlace(10)), 0);
    });
  });

  group('BytePlace', () {
    test('advances by encoded length, not code units', () {
      expect(BytePlace.start.advanced('é'), const BytePlace(2));
      expect(const BytePlace(4).advanced('a🦴'), const BytePlace(9));
    });

    test('counts a replacement as the one byte it at least stood for', () {
      final malformed = utf8.decode([0x61, 0xFF, 0x62], allowMalformed: true);
      expect(BytePlace.start.advanced(malformed), const BytePlace(3));
    });

    test('never lands past what was shown, and never stands still', () {
      // A replacement may stand for up to three malformed bytes; counting it
      // as one means a resume can re-read garbage but never skip a byte.
      final collapsed = utf8.decode([0xE2, 0x82], allowMalformed: true);
      final landed = BytePlace.start.advanced(collapsed);
      expect(landed.offset, greaterThanOrEqualTo(1));
      expect(landed.offset, lessThanOrEqualTo(2));
    });
  });

  group('Excerpt', () {
    Excerpt<LinePlace> lines(
      String text, {
      required String whole,
      LinePlace start = LinePlace.start,
    }) => Excerpt(
      text: text,
      start: start,
      extent: LinePlace.start.advanced(whole),
    );

    test('next is derived from start and text', () {
      final page = lines('one\ntw', whole: 'one\ntwo\nthree');
      expect(page.next, const LinePlace(line: 1, into: 2));
    });

    test('a whole body with no trailing newline is whole', () {
      final page = lines('one\ntwo', whole: 'one\ntwo');
      expect(page.isWhole, isTrue);
      expect(page.remaining, 0);
    });

    test('a whole body with a trailing newline is whole', () {
      final page = lines('one\ntwo\n', whole: 'one\ntwo\n');
      expect(page.isWhole, isTrue);
    });

    test('a head of the body is not whole and counts the rest', () {
      final page = lines('one\n', whole: 'one\ntwo\nthree');
      expect(page.isWhole, isFalse);
      expect(page.remaining, 2);
    });

    test('a tail of the body is not whole even when nothing remains', () {
      final page = lines(
        'three',
        start: const LinePlace(line: 2),
        whole: 'one\ntwo\nthree',
      );
      expect(page.remaining, 0);
      expect(page.isWhole, isFalse);
    });

    test('within keeps the head and next moves back with the cut', () {
      final page = lines('one\ntwo\nthree', whole: 'one\ntwo\nthree');
      final cut = page.within(5);
      expect(cut.text, 'one\nt');
      expect(cut.next, const LinePlace(line: 1, into: 1));
      expect(cut.remaining, 2);
    });

    test('within under a trailing anchor keeps the end and moves start', () {
      const whole = 'one\ntwo\nthree';
      final page = Excerpt(
        text: whole,
        start: LinePlace.start,
        extent: LinePlace.start.advanced(whole),
        anchor: Anchor.trailing,
      );
      final cut = page.within(5);
      expect(cut.text, 'three');
      expect(cut.start, const LinePlace(line: 2));
      expect(cut.next, cut.extent);
    });

    test('within with room for everything returns itself', () {
      final page = lines('one', whole: 'one');
      expect(identical(page.within(3), page), isTrue);
    });

    test('within never splits a surrogate pair on either anchor', () {
      const whole = 'ab🦴cd';
      final head = const Excerpt(
        text: whole,
        start: CharPlace.start,
        extent: CharPlace(whole.length),
      ).within(3);
      expect(head.text, 'ab');
      final tail = const Excerpt(
        text: whole,
        start: CharPlace.start,
        extent: CharPlace(whole.length),
        anchor: Anchor.trailing,
      ).within(3);
      expect(tail.text, 'cd');
    });

    test('a char window resumes exactly where the cut stopped', () {
      const whole = 'abcdefgh';
      const page = Excerpt(
        text: 'cdef',
        start: CharPlace(2),
        extent: CharPlace(whole.length),
      );
      expect(page.next, const CharPlace(6));
      expect(page.within(2).next, const CharPlace(4));
    });

    test('told returns the telling untouched when it fits', () {
      final page = lines('one\ntwo', whole: 'one\ntwo');
      expect(page.told(100, (shown) => shown.text), 'one\ntwo');
    });

    test('told gives text away until the telling fits', () {
      final page = lines('one\ntwo\nthree', whole: 'one\ntwo\nthree');
      final answer = page.told(
        12,
        (shown) => shown.isWhole
            ? shown.text
            : '${shown.text}\n[${shown.remaining} more]',
      );
      expect(answer.length, lessThanOrEqualTo(12));
      expect(answer, endsWith('more]'));
      expect(answer, startsWith('one\n'));
    });

    test('told rewrites the note around the text it cut', () {
      const whole = 'one\ntwo\nthree\nfour\nfive';
      final page = lines(whole, whole: whole);
      final answer = page.told(
        20,
        (shown) => shown.isWhole
            ? shown.text
            : '${shown.text}\n[resume ${shown.next.line}:${shown.next.into}]',
      );
      expect(answer.length, lessThanOrEqualTo(20));
      final shownText = answer.substring(0, answer.indexOf('\n[resume'));
      expect(
        answer,
        endsWith(
          '[resume ${LinePlace.start.advanced(shownText).line}'
          ':${LinePlace.start.advanced(shownText).into}]',
        ),
      );
    });

    test('told settles on the note alone when no text can fit beside it', () {
      final page = lines('one\ntwo', whole: 'one\ntwo');
      final answer = page.told(3, (shown) => '${shown.text} [a long note]');
      expect(answer, ' [a long note]');
    });

    test('told under a trailing anchor keeps the end of the text', () {
      const whole = 'one\ntwo\nthree';
      const page = Excerpt(
        text: whole,
        start: CharPlace.start,
        extent: CharPlace(whole.length),
        anchor: Anchor.trailing,
      );
      final answer = page.told(
        16,
        (shown) =>
            shown.isWhole ? shown.text : '${shown.text}\n[of ${shown.extent}]',
      );
      expect(answer.length, lessThanOrEqualTo(16));
      expect(answer, contains('three'));
    });
  });

  group('clip', () {
    test('keeps text that already fits', () {
      expect(Excerpt.clip('abc', 5), 'abc');
      expect(Excerpt.clipEnd('abc', 5), 'abc');
    });

    test('cuts to the allowance', () {
      expect(Excerpt.clip('abcdef', 4), 'abcd');
      expect(Excerpt.clipEnd('abcdef', 4), 'cdef');
    });

    test('gives nothing for no room', () {
      expect(Excerpt.clip('abc', 0), '');
      expect(Excerpt.clipEnd('abc', -1), '');
    });

    test('never splits a surrogate pair', () {
      expect(Excerpt.clip('a🦴b', 2), 'a');
      expect(Excerpt.clip('a🦴b', 3), 'a🦴');
      expect(Excerpt.clipEnd('a🦴b', 2), 'b');
      expect(Excerpt.clipEnd('a🦴b', 3), '🦴b');
    });
  });
}
