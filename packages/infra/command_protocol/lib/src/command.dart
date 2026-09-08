import 'package:command_protocol/src/answers.dart';
import 'package:command_protocol/src/availability.dart';
import 'package:command_protocol/src/command_result.dart';
import 'package:command_protocol/src/command_tier.dart';
import 'package:command_protocol/src/param.dart';
import 'package:meta/meta.dart';

/// One palette-invokable action a feature owns.
@immutable
final class Command {
  const Command({
    required this.id,
    required this.title,
    required this.description,
    required this.group,
    required this.availability,
    required this.invoke,
    this.tier = CommandTier.normal,
    this.glyph,
    this.shortcut,
    this.running,
    this.next = noParams,
  });

  /// Stable namespaced identity, e.g. `tools.stopJobs`.
  final String id;

  final String title;

  /// One sentence explaining what the command does.
  final String description;

  final CommandTier tier;

  /// One-cell symbol the palette sets before [title], when the feature has
  /// one.
  final String? glyph;

  /// Display label of the key binding that also runs this command, e.g.
  /// `Ctrl+O`, when one exists.
  final String? shortcut;

  /// Bucket label the palette groups rows under, e.g. `Tools`.
  final String group;

  /// What the palette shows while [invoke] runs; its own "Running…" when null.
  final String? running;

  /// Live gate for this command.
  final Stream<Availability> availability;

  /// The next parameter to collect, or null when the flow is complete.
  final Param? Function(Answers soFar) next;

  final Future<CommandResult> Function(Answers answers) invoke;

  /// The default flow: no parameters to collect.
  static Param? noParams(Answers soFar) => null;
}
