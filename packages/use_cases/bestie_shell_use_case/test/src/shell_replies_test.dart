import 'package:bestie_shell_use_case/src/shell_replies.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';

/// Room enough that nothing is left out for want of it, so a test that is not
/// about the allowance does not have to pick one.
const int _plenty = 100000;

/// A window holding [text], onto a recording of [totalChars] characters over
/// [totalLines] lines, still being written to where [isLive].
TranscriptPage page(
  String text, {
  int? totalChars,
  int totalLines = 1,
  int from = 0,
  bool isLive = false,
}) => TranscriptPage(
  body: Excerpt.chars(text, start: from, total: totalChars ?? text.length),
  totalLines: text.isEmpty ? 0 : totalLines,
  isLive: isLive,
);

void main() {
  group('answer', () {
    test('is the output itself when all of it was kept', () {
      expect(
        page('hello').told(ShellReply.answer, id: 'call-1', maxChars: _plenty),
        'hello',
      );
    });

    test('says so plainly when the command printed nothing', () {
      expect(
        page('').told(ShellReply.answer, id: 'call-1', maxChars: _plenty),
        '[no output]',
      );
    });

    test('says how much it left out when the output did not fit', () {
      final reply = page(
        'the end',
        totalChars: 9000,
        totalLines: 900,
      ).told(ShellReply.answer, id: 'call-1', maxChars: _plenty);

      expect(reply, startsWith('the end'));
      expect(reply, contains('900 lines, 9000 chars in all'));
      expect(reply, contains('the last 7 chars shown'));
    });

    // The id is the only handle the rest of the output can be read back
    // under, and nothing else the model is told carries it.
    test('names the call whatever it left out can be read back under', () {
      expect(
        page('the end', totalChars: 9000, totalLines: 900).told(
          ShellReply.answer,
          id: 'call-1',
          maxChars: _plenty,
        ),
        contains('"call-1"'),
      );
    });

    test('does not name the call when it kept the whole output', () {
      expect(
        page('hello').told(ShellReply.answer, id: 'call-1', maxChars: _plenty),
        isNot(contains('call-1')),
      );
    });

    test('leaves a lead to the outcome carrying it', () {
      // The output is the answer here; how the command exited is the
      // outcome's own to say.
      expect(
        page(
          'hello',
        ).told(
          ShellReply.answer,
          id: 'call-1',
          maxChars: _plenty,
          lead: 'Exited with code 0.',
        ),
        'hello',
      );
    });
  });

  group('report', () {
    test('measures the output rather than carrying it', () {
      expect(
        page(
          'the end',
          totalChars: 9000,
          totalLines: 900,
        ).told(ShellReply.report, id: 'call-1', maxChars: _plenty),
        '900 lines, 9000 chars.',
      );
    });

    test('opens with the lead it is given', () {
      expect(
        page(
          'hello',
        ).told(
          ShellReply.report,
          id: 'call-1',
          maxChars: _plenty,
          lead: 'Exited with code 0.',
        ),
        'Exited with code 0. 1 lines, 5 chars.',
      );
    });

    test('measures nothing as nothing', () {
      expect(
        page(
          '',
        ).told(
          ShellReply.report,
          id: 'call-1',
          maxChars: _plenty,
          lead: 'Exited with code 0.',
        ),
        'Exited with code 0. [no output]',
      );
    });
  });

  group('page', () {
    test('says how much it showed and where to carry on from', () {
      final read = page(
        'first page',
        totalChars: 300,
      ).read('call-1', maxChars: _plenty);

      expect(read, startsWith('first page'));
      expect(read, contains('chars 0 to 10 of 300'));
      expect(read, contains('290 to go'));
      expect(read, contains('bash_read(id: "call-1", offset: 10)'));
    });

    test('leaves the last page to speak for itself', () {
      final last = page('the end', totalChars: 300, from: 293);

      expect(last.read('call-1', maxChars: _plenty), 'the end');
    });

    test('says plainly that the command printed nothing', () {
      expect(page('').read('call-1', maxChars: _plenty), '[no output]');
    });

    test('says how far the record goes when asked past its end', () {
      // Told the extent, the model can ask again for somewhere that exists
      // instead of reading an empty answer as "the output is gone".
      final read = page(
        '',
        totalChars: 300,
        from: 900,
      ).read('call-1', maxChars: _plenty);

      expect(read, contains('nothing at 900'));
      expect(read, contains('300 chars in all'));
    });

    test('says the end of a running shell is only the end so far', () {
      // The same page off a finished recording is the whole story, so the
      // last page of a running one has to say that it is not.
      final read = page(
        'so far',
        totalChars: 299,
        from: 293,
        isLive: true,
      ).read('call-1', maxChars: _plenty);

      expect(read, startsWith('so far'));
      expect(read, contains('Caught up at 299'));
      expect(read, contains('Still running'));
    });

    test('leaves waiting to whoever is waiting', () {
      // A model told it will hear about the finish has no reason to spend a
      // call finding out, so the page says so rather than only where to look.
      final read = page(
        'so far',
        totalChars: 299,
        from: 293,
        isLive: true,
      ).read('call-1', maxChars: _plenty);

      expect(read, contains('notifies on completion'));
    });

    test('is caught up rather than empty at the end of a running shell', () {
      // Nothing new yet reads as "the output is gone" unless it says what it
      // actually is.
      final read = page(
        '',
        totalChars: 300,
        from: 300,
        isLive: true,
      ).read('call-1', maxChars: _plenty);

      expect(read, contains('Caught up at 300'));
      expect(read, isNot(contains('nothing at')));
    });

    test('still points somewhere real when a running shell is behind it', () {
      // Past the end of what has been written is where the next page starts,
      // so the offset it hands back is one a further read can use.
      final read = page(
        '',
        totalChars: 300,
        from: 300,
        isLive: true,
      ).read('call-1', maxChars: _plenty);

      expect(read, contains('300'));
    });
  });

  group('what a telling may cost', () {
    // Every figure a note quotes grows with the recording, so the output is
    // what gives way for them.
    test('holds the output and its note inside the allowance', () {
      final told =
          page(
            'x' * 5000,
            totalChars: 999999999,
            totalLines: 9999999,
            from: 999994999,
          ).told(
            ShellReply.answer,
            id: 'a-rather-long-call-id-1234',
            maxChars: 200,
          );

      expect(told.length, lessThanOrEqualTo(200));
      expect(told, contains('999999999 chars in all'));
      expect(told, contains('"a-rather-long-call-id-1234"'));
    });

    test('cuts even the whole of it down to what there is room for', () {
      // What a recording was allowed to keep and what is left to tell it in
      // are not the same figure once a message goes above it.
      final told = page(
        'x' * 300,
      ).told(ShellReply.answer, id: 'call-1', maxChars: 200);

      expect(told.length, lessThanOrEqualTo(200));
      expect(told, contains('300 chars in all'));
    });

    test('counts what it kept, not what it was handed', () {
      final told = page(
        'x' * 5000,
        totalChars: 9000,
        totalLines: 900,
      ).told(ShellReply.answer, id: 'call-1', maxChars: 200);

      final shown = told.split('\n\n').first;
      expect(told, contains('the last ${shown.length} chars shown'));
    });

    test('holds a page and its note inside the allowance', () {
      final read = page(
        'x' * 5000,
        totalChars: 999999999,
        from: 123456789,
      ).read('a-rather-long-call-id-1234', maxChars: 200);

      expect(read.length, lessThanOrEqualTo(200));
      expect(read, contains('chars 123456789 to'));
    });

    test('sends a reader on from where the page it showed stopped', () {
      // The page was cut after the note was priced, so what the note quotes
      // has to be where the cut landed rather than where the read reached.
      final read = page(
        'x' * 5000,
        totalChars: 999999999,
        from: 100,
      ).read('call-1', maxChars: 200);

      final shown = read.split('\n\n').first;
      expect(read, contains('offset: ${100 + shown.length}'));
      expect(read, contains('chars 100 to ${100 + shown.length}'));
    });

    test('leaves room for whichever note it turns out to need', () {
      // A page that reached the end of a running recording says it is caught
      // up; cutting it means it no longer has, and the other note is longer.
      final read = page(
        'x' * 300,
        totalChars: 300,
        isLive: true,
      ).read('call-1', maxChars: 200);

      expect(read.length, lessThanOrEqualTo(200));
      expect(read, contains('to go'));
    });
  });
}
