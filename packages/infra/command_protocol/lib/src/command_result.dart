import 'package:meta/meta.dart';

/// Outcome of invoking a command.
@immutable
sealed class CommandResult {
  const CommandResult();
}

final class CommandRan extends CommandResult {
  const CommandRan();
}

final class CommandRejected extends CommandResult {
  const CommandRejected(this.reason);

  final String reason;
}
