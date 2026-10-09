import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

void main() {
  const command = ProgramCommand(executable: 'dart', arguments: ['run', 'x']);

  test('compares by executable and arguments', () {
    expect(
      command,
      const ProgramCommand(executable: 'dart', arguments: ['run', 'x']),
    );
    expect(
      command.hashCode,
      const ProgramCommand(
        executable: 'dart',
        arguments: ['run', 'x'],
      ).hashCode,
    );
    expect(
      command,
      isNot(const ProgramCommand(executable: 'dart', arguments: ['run', 'y'])),
    );
    expect(command, isNot(const ProgramCommand(executable: 'dart')));
    expect(command, isNot(const ProgramCommand(executable: 'other')));
  });

  test('prints as a command line', () {
    expect(command.toString(), 'dart run x');
  });
}
