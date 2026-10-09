import 'package:command_protocol/src/answers.dart';
import 'package:command_protocol/src/command_result.dart';
import 'package:command_protocol/src/pane.dart';
import 'package:command_protocol/src/param.dart';
import 'package:meta/meta.dart';

/// What the palette does when a command is activated.
@immutable
sealed class CommandBody {
  const CommandBody();
}

/// Collects parameters one at a time, then runs.
final class CommandFlow extends CommandBody {
  const CommandFlow({required this.invoke, this.next = noParams, this.running});

  /// The next parameter to collect, or null when the flow is complete.
  final Param? Function(Answers soFar) next;

  final Future<CommandResult> Function(Answers answers) invoke;

  /// What the palette shows while [invoke] runs; its own "Running…" when null.
  final String? running;

  /// The default flow: no parameters to collect.
  static Param? noParams(Answers soFar) => null;
}

/// Opens [pane] inside the palette.
final class CommandPane extends CommandBody {
  const CommandPane(this.pane);

  final Pane pane;
}
