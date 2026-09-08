import 'dart:async';

import 'package:bestie_ui/src/effects/overlay_tick.dart';
import 'package:bestie_ui/src/theme/theme_effects.dart';
import 'package:nocterm/nocterm.dart';

/// Advances a glitter [tick] on the shared overlay clock while theme effects
/// are on, and holds it still otherwise.
mixin GlitterClock<T extends StatefulComponent> on State<T> {
  Timer? _timer;

  /// Starts at one so a still field already carries a scatter of sparkles.
  int tick = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer(animate: ThemeEffects.of(context));
  }

  void _syncTimer({required bool animate}) {
    if (animate == (_timer != null)) return;
    _timer?.cancel();
    _timer = null;
    if (!animate) return;
    _timer = Timer.periodic(overlayTickInterval, (_) {
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
