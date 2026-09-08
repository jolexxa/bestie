import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

final class _FakeContribution implements CommandContribution {
  _FakeContribution(this.commands);

  @override
  final List<Command> commands;
}

Command _command(String id) => Command(
  id: id,
  title: id,
  description: '',
  group: 'Test',
  availability: Stream.value(const Available()),
  invoke: (_) async => const CommandRan(),
);

void main() {
  group('CommandsUseCase', () {
    test('snapshots contributions in order into one stable catalog', () {
      final stop = _command('tools.stopJobs');
      final download = _command('models.download');
      final useCase = CommandsUseCase(
        contributions: [
          _FakeContribution([stop]),
          _FakeContribution([download]),
        ],
      );
      expect(useCase.commands.map((c) => c.id), [
        'tools.stopJobs',
        'models.download',
      ]);
      expect(useCase.commands.first, same(stop));
      expect(useCase.commands, same(useCase.commands));
      expect(useCase.commands.clear, throwsUnsupportedError);
    });

    test('tolerates an empty contribution list', () {
      expect(CommandsUseCase(contributions: const []).commands, isEmpty);
    });

    test('rejects duplicate command ids', () {
      expect(
        () => CommandsUseCase(
          contributions: [
            _FakeContribution([_command('a.b')]),
            _FakeContribution([_command('a.b')]),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
