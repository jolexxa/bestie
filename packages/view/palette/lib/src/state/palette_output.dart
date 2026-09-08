import 'package:intentions/intentions.dart';

@model
sealed class PaletteOutput {
  const PaletteOutput();
}

@model
final class PaletteStateUpdated extends PaletteOutput {
  const PaletteStateUpdated();
}

/// Asks the host (the router) to hide the palette overlay.
@model
final class CloseRequested extends PaletteOutput {
  const CloseRequested();
}

/// The list selection moved; the view keeps the row visible.
@model
final class CursorMoved extends PaletteOutput {
  const CursorMoved(this.index);

  final int index;
}
