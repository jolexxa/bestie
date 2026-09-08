import 'package:bestie_ui/bestie_ui.dart' show AppMode;
import 'package:intentions/intentions.dart';

@model
sealed class RouterInput {
  const RouterInput();
}

@model
final class NextMode extends RouterInput {
  const NextMode();
}

/// Jump directly to [mode]. The mouse equivalent of cycling with
/// `NextMode`/`PreviousMode` — a click on a mode tab lands on it.
@model
final class SwitchToMode extends RouterInput {
  const SwitchToMode(this.mode);

  final AppMode mode;
}

@model
final class PreviousMode extends RouterInput {
  const PreviousMode();
}

/// The app shell reported a change to the config overlay's visibility.
@model
final class ConfigOpenChanged extends RouterInput {
  const ConfigOpenChanged({required this.open});

  final bool open;
}

/// The app shell reported a change to the palette overlay's visibility.
@model
final class PaletteOpenChanged extends RouterInput {
  const PaletteOpenChanged({required this.open});

  final bool open;
}
