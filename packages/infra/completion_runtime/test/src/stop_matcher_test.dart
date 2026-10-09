import 'package:completion_runtime/src/stop_matcher.dart';
import 'package:test/test.dart';

Matcher _unmatched(String released) => isA<StopUnmatched>().having(
  (scan) => scan.released,
  'released',
  released,
);

Matcher _matched(String released) => isA<StopMatched>().having(
  (scan) => scan.released,
  'released',
  released,
);

void main() {
  group('StopMatcher', () {
    test('passes text straight through without stops', () {
      final matcher = StopMatcher(const []);

      expect(matcher.add('hello <'), _unmatched('hello <'));
      expect(matcher.flush(), isEmpty);
    });

    test('ignores empty stops', () {
      final matcher = StopMatcher(const ['']);

      expect(matcher.add('anything'), _unmatched('anything'));
    });

    test('releases the text before a stop and nothing after it', () {
      final matcher = StopMatcher(const ['STOP']);

      expect(matcher.add('one STOP two'), _matched('one '));
      expect(matcher.flush(), isEmpty);
    });

    test('holds back a tail that could begin a stop', () {
      final matcher = StopMatcher(const ['<|end|>']);

      expect(matcher.add('answer <|e'), _unmatched('answer '));
      expect(matcher.add('nd|> more'), _matched(''));
    });

    test('releases held text once it cannot begin a stop', () {
      final matcher = StopMatcher(const ['<|end|>']);

      expect(matcher.add('a <|'), _unmatched('a '));
      expect(matcher.add('x'), _unmatched('<|x'));
    });

    test('holds back no more than the longest stop could need', () {
      final matcher = StopMatcher(const ['abc']);

      expect(matcher.add('xxab'), _unmatched('xx'));
      expect(matcher.add('ab'), _unmatched('ab'));
    });

    test('finds a stop split across many pieces', () {
      final matcher = StopMatcher(const ['STOP']);

      expect(matcher.add('S'), _unmatched(''));
      expect(matcher.add('T'), _unmatched(''));
      expect(matcher.add('O'), _unmatched(''));
      expect(matcher.add('P!'), _matched(''));
    });

    test('ends at the earliest of several stops', () {
      final matcher = StopMatcher(const ['zzz', 'b', 'a']);

      expect(matcher.add('xba'), _matched('x'));
    });

    test('flush releases what is held and forgets it', () {
      final matcher = StopMatcher(const ['STOP'])..add('fin ST');

      expect(matcher.flush(), 'ST');
      expect(matcher.flush(), isEmpty);
    });
  });
}
