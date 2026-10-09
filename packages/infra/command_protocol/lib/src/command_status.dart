import 'package:command_protocol/src/pane_tone.dart';
import 'package:meta/meta.dart';

/// What a command's feature is doing right now, set at the end of the
/// command's palette row, e.g. how far its downloads have got.
@immutable
final class CommandStatus {
  const CommandStatus(this.spans, {this.progress});

  final List<PaneSpan> spans;

  /// Share of the work done, from 0 to 1, drawn as a short bar after
  /// [spans]; no bar when null.
  final double? progress;
}
