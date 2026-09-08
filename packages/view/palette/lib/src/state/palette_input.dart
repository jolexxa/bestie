import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

@model
sealed class PaletteInput {
  const PaletteInput();
}

/// The palette overlay became visible.
@model
final class OpenPalette extends PaletteInput {
  const OpenPalette();
}

/// The palette overlay became hidden.
@model
final class ClosePalette extends PaletteInput {
  const ClosePalette();
}

/// The user asked to dismiss the palette.
@model
final class RequestClose extends PaletteInput {
  const RequestClose();
}

@model
final class QueryChanged extends PaletteInput {
  const QueryChanged(this.query);

  final String query;
}

@model
final class MoveSelection extends PaletteInput {
  const MoveSelection(this.delta);

  final int delta;
}

/// Run the selected command (or begin collecting its parameters).
@model
final class Activate extends PaletteInput {
  const Activate();
}

/// The current param's option list arrived on its stream.
@model
final class OptionsLoaded extends PaletteInput {
  const OptionsLoaded(this.options);

  final List<Option<Object?>> options;
}

@model
final class OptionQueryChanged extends PaletteInput {
  const OptionQueryChanged(this.query);

  final String query;
}

/// Toggle the selected option in a multi-choice picker.
@model
final class ToggleOption extends PaletteInput {
  const ToggleOption();
}

/// Submit the entered text for a text or number param.
@model
final class SubmitText extends PaletteInput {
  const SubmitText(this.text);

  final String text;
}

/// Submit the selected option(s) for a choice or multi-choice param.
@model
final class SubmitChoice extends PaletteInput {
  const SubmitChoice();
}

/// Step back one collected answer, or return to browsing from the first.
@model
final class Back extends PaletteInput {
  const Back();
}

@model
final class AvailabilityChanged extends PaletteInput {
  const AvailabilityChanged(this.commandId, this.availability);

  final String commandId;
  final Availability availability;
}

@model
final class InvokeSettled extends PaletteInput {
  const InvokeSettled(this.result);

  final CommandResult result;
}
