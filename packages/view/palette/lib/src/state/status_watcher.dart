import 'dart:async';

import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Owns the subscriptions to the listed commands' status streams.
@PartOf(PaletteCubit)
final class StatusWatcher {
  StatusWatcher({required this.onStatus});

  /// Called with a command's new status; null when it has nothing to report
  /// or its stream failed.
  final void Function(Command command, CommandStatus? status) onStatus;

  final List<StreamSubscription<CommandStatus?>> _subs = [];

  /// Follows [commands]' statuses, dropping whatever it followed before.
  void watch(List<Command> commands) {
    stop();
    for (final command in commands) {
      _subs.add(
        command.status.listen(
          (status) => onStatus(command, status),
          onError: (Object _) => onStatus(command, null),
        ),
      );
    }
  }

  void stop() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
  }
}
