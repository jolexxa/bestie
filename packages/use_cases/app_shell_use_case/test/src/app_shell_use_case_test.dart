import 'package:app_shell_use_case/app_shell_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

void main() {
  late AppShellUseCase useCase;

  setUp(() => useCase = AppShellUseCase());

  tearDown(() => useCase.dispose());

  group('overlay state', () {
    test('both overlays start closed', () {
      expect(useCase.configOpen, isFalse);
      expect(useCase.paletteOpen, isFalse);
    });

    test('toggleConfig flips config and emits the change', () {
      final emitted = <bool>[];
      useCase.configOpenChanges.listen(emitted.add);

      useCase.toggleConfig();
      expect(useCase.configOpen, isTrue);

      useCase.toggleConfig();
      expect(useCase.configOpen, isFalse);

      return Future<void>.delayed(Duration.zero, () {
        expect(emitted, [true, false]);
      });
    });

    test('togglePalette flips palette and emits the change', () {
      final emitted = <bool>[];
      useCase.paletteOpenChanges.listen(emitted.add);

      useCase.togglePalette();
      expect(useCase.paletteOpen, isTrue);

      useCase.togglePalette();
      expect(useCase.paletteOpen, isFalse);

      return Future<void>.delayed(Duration.zero, () {
        expect(emitted, [true, false]);
      });
    });

    test('opening config closes an open palette', () async {
      final palette = <bool>[];
      useCase.paletteOpenChanges.listen(palette.add);

      useCase
        ..openPalette()
        ..openConfig();

      expect(useCase.configOpen, isTrue);
      expect(useCase.paletteOpen, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(palette, [true, false]);
    });

    test('opening palette closes an open config', () {
      useCase
        ..openConfig()
        ..openPalette();

      expect(useCase.paletteOpen, isTrue);
      expect(useCase.configOpen, isFalse);
    });

    test('a redundant close emits nothing', () async {
      final emitted = <bool>[];
      useCase.configOpenChanges.listen(emitted.add);

      useCase.closeConfig();

      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);
    });
  });

  group('nav.openConfig command', () {
    test('is contributed', () {
      expect(useCase.commands.map((c) => c.id), contains('nav.openConfig'));
    });

    test('is always available', () async {
      final command = useCase.commands.firstWhere(
        (c) => c.id == 'nav.openConfig',
      );
      final gates = <Availability>[];
      final sub = command.availability.listen(gates.add);
      addTearDown(sub.cancel);
      await Future<void>.delayed(Duration.zero);
      expect(gates.first, isA<Available>());
    });

    test('opens the config overlay when invoked', () async {
      final command = useCase.commands.firstWhere(
        (c) => c.id == 'nav.openConfig',
      );
      expect(await command.invoke(const Answers.empty()), isA<CommandRan>());
      expect(useCase.configOpen, isTrue);
    });
  });
}
