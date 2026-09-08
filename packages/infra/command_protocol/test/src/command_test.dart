import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

final class _FakeContribution implements CommandContribution {
  _FakeContribution(this.commands);

  @override
  final List<Command> commands;
}

void main() {
  group('Availability', () {
    test('states carry their reasons', () {
      const gate = Unavailable('no active jobs');
      expect(gate.reason, 'no active jobs');
      final label = switch (gate as Availability) {
        Available() => 'on',
        Unavailable(:final reason) => reason,
      };
      expect(label, 'no active jobs');
      expect(const Available(), isA<Availability>());
    });
  });

  group('CommandResult', () {
    test('states carry their reasons', () {
      const rejected = CommandRejected('stale');
      final label = switch (rejected as CommandResult) {
        CommandRan() => 'ran',
        CommandRejected(:final reason) => reason,
      };
      expect(label, 'stale');
      expect(const CommandRan(), isA<CommandResult>());
    });
  });

  group('Command', () {
    test('defaults to a parameterless flow', () async {
      var invoked = false;
      final command = Command(
        id: 'tools.stopJobs',
        title: 'Stop all jobs',
        description: 'Cancel every job',
        group: 'Tools',
        availability: Stream.value(const Available()),
        invoke: (answers) async {
          invoked = true;
          return const CommandRan();
        },
      );
      expect(command.next(const Answers.empty()), isNull);
      expect(await command.invoke(const Answers.empty()), isA<CommandRan>());
      expect(invoked, isTrue);
      expect(await command.availability.first, isA<Available>());
      expect(command.description, 'Cancel every job');
      expect(command.tier, CommandTier.normal);
    });

    test('primary tier marks key actions', () {
      final command = Command(
        id: 'provider.select_model',
        title: 'Select model',
        description: 'Choose the model',
        group: 'Provider',
        tier: CommandTier.primary,
        availability: Stream.value(const Available()),
        invoke: (_) async => const CommandRan(),
      );
      expect(command.tier, CommandTier.primary);
      expect(command.glyph, isNull);
      expect(command.shortcut, isNull);
    });

    test('carries a glyph and a shortcut label when the feature has them', () {
      final command = Command(
        id: 'nav.openConfig',
        title: 'Open configuration',
        description: 'Edit settings',
        group: 'App',
        glyph: '⚙',
        shortcut: 'Ctrl+O',
        availability: Stream.value(const Available()),
        invoke: (_) async => const CommandRan(),
      );
      expect(command.glyph, '⚙');
      expect(command.shortcut, 'Ctrl+O');
    });

    test('flows collect dependent params until next returns null', () async {
      const model = ParamKey<String>('model');
      const quant = ParamKey<String>('quant');
      final command = Command(
        id: 'models.download',
        title: 'Download model',
        description: 'Fetch a model',
        group: 'Models',
        availability: Stream.value(const Available()),
        next: (soFar) {
          final chosenModel = soFar.maybe(model);
          if (chosenModel == null) {
            return ChoiceParam<String>.fixed(
              key: model,
              label: 'Model',
              options: const [Option(value: 'llama', label: 'Llama')],
            );
          }
          if (soFar.maybe(quant) == null) {
            return ChoiceParam<String>.fixed(
              key: quant,
              label: 'Quantization for $chosenModel',
              options: const [Option(value: 'q4', label: 'Q4_K_M')],
            );
          }
          return null;
        },
        invoke: (answers) async =>
            answers.get(model) == 'llama' && answers.get(quant) == 'q4'
            ? const CommandRan()
            : const CommandRejected('unexpected answers'),
      );

      var answers = const Answers.empty();
      final first = command.next(answers)! as ChoiceParam<String>;
      expect(first.key, model);
      answers = answers.put(model, 'llama');

      final second = command.next(answers)! as ChoiceParam<String>;
      expect(second.label, 'Quantization for llama');
      answers = answers.put(quant, 'q4');

      expect(command.next(answers), isNull);
      expect(await command.invoke(answers), isA<CommandRan>());
    });
  });

  group('CommandContribution', () {
    test('exposes stable command instances', () {
      final command = Command(
        id: 'a.b',
        title: 'B',
        description: '',
        group: 'A',
        availability: Stream.value(const Available()),
        invoke: (_) async => const CommandRan(),
      );
      final contribution = _FakeContribution([command]);
      expect(contribution.commands.single, same(command));
      expect(contribution.commands.single, same(contribution.commands.single));
    });
  });
}
