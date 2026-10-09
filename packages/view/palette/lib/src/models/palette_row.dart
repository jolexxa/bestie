import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// One command row the palette list renders: the command plus its most
/// recently observed availability and status.
@model
@immutable
final class PaletteRow {
  const PaletteRow({
    required this.command,
    required this.availability,
    this.status,
  });

  final Command command;
  final Availability availability;

  /// What the command's feature last reported; null when it has nothing to
  /// report.
  final CommandStatus? status;
}
