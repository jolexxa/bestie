import 'dart:async';

import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:config_repository/config_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockConfigRepository extends Mock implements ConfigRepository {}

void main() {
  group('Mascot', () {
    test('parses each id to its mascot', () {
      for (final mascot in Mascot.values) {
        expect(Mascot.parse(mascot.id), mascot);
      }
    });

    test('parses unknown ids to the cow', () {
      expect(Mascot.parse('capybara'), Mascot.cow);
    });
  });

  group('MascotConfigKeys', () {
    test('defaults to the cow', () {
      final keys = MascotConfigKeys.defaults();
      expect(keys.mascot.defaultValue(), Mascot.cow.id);
    });
  });

  group('MascotConfigContribution', () {
    test('contributes one global entry offering every mascot', () {
      final contribution = MascotConfigContribution();
      final entry = contribution.entries.single;
      expect(entry.key.id, contribution.configKeys.mascot.id);

      final field = entry.field as EnumField<String>;
      expect(field.options(), [for (final mascot in Mascot.values) mascot.id]);
      expect(field.optionLabel(Mascot.dino.id), Mascot.dino.label);
    });
  });

  group('MascotUseCase', () {
    late _MockConfigRepository config;
    late MascotConfigKeys configKeys;
    late MascotUseCase useCase;

    setUp(() {
      config = _MockConfigRepository();
      configKeys = MascotConfigKeys.defaults();
      useCase = MascotUseCase(config: config, configKeys: configKeys);
    });

    test('resolves the selected mascot from config', () {
      when(
        () => config.resolve(configKeys.mascot.global),
      ).thenReturn(Mascot.dino.id);

      expect(useCase.mascot, Mascot.dino);
    });

    test('resolves unknown selections to the cow', () {
      when(
        () => config.resolve(configKeys.mascot.global),
      ).thenReturn('capybara');

      expect(useCase.mascot, Mascot.cow);
    });

    test('emits each selection change as a mascot', () async {
      final changes = StreamController<String>();
      addTearDown(changes.close);
      when(
        () => config.watch(configKeys.mascot.global),
      ).thenAnswer((_) => changes.stream);

      final emitted = useCase.mascotChanges.toList();
      changes
        ..add(Mascot.dino.id)
        ..add('capybara')
        ..add(Mascot.cow.id);
      await changes.close();

      expect(await emitted, [Mascot.dino, Mascot.cow, Mascot.cow]);
    });
  });
}
