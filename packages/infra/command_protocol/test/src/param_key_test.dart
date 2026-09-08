import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ParamKey', () {
    test('equality is by id', () {
      const a = ParamKey<String>('model');
      const b = ParamKey<String>('model');
      const c = ParamKey<String>('quant');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals('model')));
      expect(a.hashCode, b.hashCode);
    });
  });
}
