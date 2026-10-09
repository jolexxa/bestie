import 'package:command_protocol/src/availability.dart';
import 'package:command_protocol/src/command_body.dart';
import 'package:command_protocol/src/command_status.dart';
import 'package:command_protocol/src/command_tier.dart';
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
    required this.body,
    this.tier = CommandTier.normal,
    this.glyph,
    this.shortcut,
    this.status = const Stream.empty(),
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

  /// Live gate for this command.
  final Stream<Availability> availability;

  /// What the command's feature is doing, live, whether or not the command
  /// can run; null while there is nothing to report. Listened to again
  /// whenever the command list comes back into view.
  final Stream<CommandStatus?> status;

  /// What activating the command does.
  final CommandBody body;
}
