import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Feature use case for the command palette.
@useCase
class CommandsUseCase {
  CommandsUseCase({required List<CommandContribution> contributions})
    : commands = List.unmodifiable([
        for (final contribution in contributions) ...contribution.commands,
      ]) {
    final ids = <String>{};
    for (final command in commands) {
      if (!ids.add(command.id)) {
        throw ArgumentError.value(
          command.id,
          'contributions',
          'contributed more than once',
        );
      }
    }
  }

  /// Every contributed command, in contribution order.
  final List<Command> commands;
}
