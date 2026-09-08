import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('customEditable defaults', () {
    test('NumericField is customEditable', () {
      final field = NumericField<int>(
        label: 'n',
        description: 'd',
        min: 0,
        max: 10,
        step: 1,
      );
      expect(field.customEditable, isTrue);
    });

    test('BoolField is not customEditable', () {
      final field = BoolField(label: 'b', description: 'd');
      expect(field.customEditable, isFalse);
    });

    test('EnumField is not customEditable', () {
      final field = EnumField<String>(
        label: 'e',
        description: 'd',
        options: () => const ['a', 'b'],
        optionLabel: (s) => s,
      );
      expect(field.customEditable, isFalse);
    });

    test('OpaqueField defaults to customEditable', () {
      final field = OpaqueField<String>(label: 'o', description: 'd');
      expect(field.customEditable, isTrue);
    });
  });

  group('NumericField<double>', () {
    final field = NumericField<double>(
      label: 'Temp',
      description: 'sampling',
      min: 0,
      max: 2,
      step: 0.1,
    );

    test('adjust steps and clamps', () {
      expect(field.adjust(0.5, 1), closeTo(0.6, 1e-9));
      expect(field.adjust(0, -5), 0);
      expect(field.adjust(2, 5), 2);
    });

    test('format uses step precision', () {
      expect(field.format(0.7), '0.7');
      expect(field.format(1.25), '1.3');
    });

    test('parse double / null on garbage', () {
      expect(field.parse('1.5'), 1.5);
      expect(field.parse('not'), isNull);
    });

    test('validate flags out-of-range', () {
      expect(field.validate(1), isA<Valid>());
      expect(field.validate(-1), isA<Invalid>());
      expect(
        (field.validate(3) as Invalid).message,
        contains('Must be between'),
      );
    });

    test('default maxLines is 1', () {
      expect(field.maxLines, 1);
    });
  });

  group('NumericField<int>', () {
    final field = NumericField<int>(
      label: 'Top-K',
      description: 'top-k',
      min: 0,
      max: 200,
      step: 1,
    );

    test('format prints whole numbers', () {
      expect(field.format(40), '40');
    });

    test('parse handles ints', () {
      expect(field.parse('42'), 42);
      expect(field.parse('zzz'), isNull);
    });

    test('adjust preserves int type', () {
      final next = field.adjust(40, 5);
      expect(next, 45);
      expect(next, isA<int>());
    });
  });

  group('BoolField', () {
    final field = BoolField(label: 'Flag', description: 'a flag');

    test('adjust toggles', () {
      expect(field.adjust(true, 1), false);
      expect(field.adjust(false, -3), true);
    });

    test('format / parse', () {
      expect(field.format(true), 'true');
      expect(field.format(false), 'false');
      expect(field.parse('TRUE'), true);
      expect(field.parse('1'), true);
      expect(field.parse('false'), false);
      expect(field.parse('0'), false);
      expect(field.parse('garbage'), isNull);
    });

    test('validate is always valid', () {
      expect(field.validate(true), isA<Valid>());
      expect(field.validate(false), isA<Valid>());
    });
  });

  group('EnumField<String>', () {
    final field = EnumField<String>(
      label: 'Mode',
      description: 'a mode',
      options: () => const ['a', 'b', 'c'],
      optionLabel: (s) => s.toUpperCase(),
    );

    test('adjust cycles', () {
      expect(field.adjust('a', 1), 'b');
      expect(field.adjust('c', 1), 'a');
      expect(field.adjust('a', -1), 'c');
    });

    test('adjust falls back to first when current not in list', () {
      expect(field.adjust('z', 1), 'a');
    });

    test('format uses optionLabel', () {
      expect(field.format('b'), 'B');
    });

    test('parse case-insensitive', () {
      expect(field.parse('a'), 'a');
      expect(field.parse('B'), 'b');
      expect(field.parse('zzz'), isNull);
    });

    test('validate flags non-members', () {
      expect(field.validate('a'), isA<Valid>());
      expect(field.validate('z'), isA<Invalid>());
      expect(
        (field.validate('z') as Invalid).message,
        contains('one of'),
      );
    });
  });

  group('OpaqueField<String>', () {
    final field = OpaqueField<String>(label: 'Name', description: 'opaque');

    test('adjust is a no-op', () {
      expect(field.adjust('hello', 1), 'hello');
      expect(field.adjust('hello', -3), 'hello');
    });

    test('format is identity-ish', () {
      expect(field.format('abc'), 'abc');
    });

    test('parse returns input as-is', () {
      expect(field.parse('xyz'), 'xyz');
    });

    test('validate is always valid', () {
      expect(field.validate('whatever'), isA<Valid>());
    });

    test('is not secret unless asked', () {
      expect(field.secret, isFalse);
      expect(
        OpaqueField<String>(
          label: 'Key',
          description: 'hush',
          secret: true,
        ).secret,
        isTrue,
      );
      expect(
        NumericField<int>(
          label: 'n',
          description: 'd',
          min: 0,
          max: 1,
          step: 1,
        ).secret,
        isFalse,
      );
    });

    test('maxLines defaults to 1, configurable via ctor', () {
      expect(field.maxLines, 1);
      final multi = OpaqueField<String>(
        label: 'Long',
        description: 'big',
        maxLines: 8,
      );
      expect(multi.maxLines, 8);
    });
  });
}
