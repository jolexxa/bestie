import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigCodecs', () {
    test('double accepts JSON ints and doubles', () {
      expect(ConfigCodecs.doubles.decode(1), 1.0);
      expect(ConfigCodecs.doubles.decode(1.25), 1.25);
    });

    test('int accepts ints and integral doubles only', () {
      expect(ConfigCodecs.integers.decode(4), 4);
      expect(ConfigCodecs.integers.decode(4.0), 4);
      expect(ConfigCodecs.integers.decode(4.5), isNull);
    });

    test('bool and string reject wrong-typed junk', () {
      expect(ConfigCodecs.booleans.decode(true), isTrue);
      expect(ConfigCodecs.booleans.decode('true'), isNull);
      expect(ConfigCodecs.strings.decode('cow'), 'cow');
      expect(ConfigCodecs.strings.decode(123), isNull);
    });

    test('map preserves unknown string-keyed JSON objects', () {
      final raw = {
        'llama_cpp': {'flashAttentionEnabled': true},
        'future_backend': {'opaque': 1},
      };

      expect(ConfigCodecs.maps.decode(raw), raw);
    });

    test('string list accepts only lists of strings', () {
      expect(ConfigCodecs.stringLists.decode(<String>['a', 'b']), ['a', 'b']);
      expect(ConfigCodecs.stringLists.decode(<Object?>['a', 'b']), ['a', 'b']);
      expect(ConfigCodecs.stringLists.decode(<Object?>[]), isEmpty);
      expect(ConfigCodecs.stringLists.decode(<Object?>['a', 1]), isNull);
      expect(ConfigCodecs.stringLists.decode('a'), isNull);
    });

    test('encode passes values through', () {
      expect(ConfigCodecs.doubles.encode(0.7), 0.7);
      expect(ConfigCodecs.strings.encode(null), isNull);
    });
  });
}
