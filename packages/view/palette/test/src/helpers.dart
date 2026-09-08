import 'dart:async';

import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:command_protocol/command_protocol.dart';

final class FakeContribution implements CommandContribution {
  FakeContribution(this.commands);

  @override
  final List<Command> commands;
}

CommandsUseCase catalogOf(List<Command> commands) =>
    CommandsUseCase(contributions: [FakeContribution(commands)]);

Command simpleCommand(
  String id, {
  String group = 'Test',
  String description = '',
  CommandTier tier = CommandTier.normal,
  String? glyph,
  String? shortcut,
  String? running,
  Stream<Availability>? availability,
  Future<CommandResult> Function(Answers answers)? invoke,
  Param? Function(Answers soFar)? next,
}) => Command(
  id: id,
  title: id,
  description: description,
  tier: tier,
  glyph: glyph,
  shortcut: shortcut,
  running: running,
  group: group,
  availability: availability ?? const Stream.empty(),
  invoke: invoke ?? (_) async => const CommandRan(),
  next: next ?? Command.noParams,
);
