import 'package:files_data_source/files_data_source.dart';
import 'package:test/test.dart';

void main() {
  group('StoredBody', () {
    test('counts its lines through the head it kept', () {
      const body = StoredBody(
        head: Excerpt(
          text: 'one\ntwo',
          start: LinePlace.start,
          extent: LinePlace(line: 99, into: 5),
        ),
        totalChars: 900,
        storedAt: '/store/output',
      );

      expect(body.totalLines, 100);
      expect(body.head.isWhole, isFalse);
    });

    test('a head holding everything is whole', () {
      const body = StoredBody(
        head: Excerpt(
          text: 'one\ntwo',
          start: LinePlace.start,
          extent: LinePlace(line: 1, into: 3),
        ),
        totalChars: 7,
        storedAt: '/store/output',
      );

      expect(body.head.isWhole, isTrue);
      expect(body.totalLines, 2);
    });
  });
}
