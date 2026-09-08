import 'package:command_protocol/src/command.dart';

/// A feature's self-owned palette commands, collected at the composition root
/// the same way tool responders and config contributions are.
abstract interface class CommandContribution {
  Iterable<Command> get commands;
}
