import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Rebuilds on a one-second beat while running, and holds still otherwise.
mixin RunningClock<T extends StatefulComponent> on State<T> {
  Timer? _timer;

  /// Beats so far, for a frame that changes with every rebuild.
  int tick = 0;

  /// How often to rebuild while running.
  Duration get runningClockInterval => const Duration(seconds: 1);

  /// Starts the beat when [running] and stops it when not; already being in
  /// that state is a no-op.
  void syncRunningClock({required bool running}) {
    if (running == (_timer != null)) return;
    _timer?.cancel();
    _timer = null;
    if (!running) return;
    _timer = Timer.periodic(runningClockInterval, (_) {
      if (!mounted) return;
      setState(() => tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
