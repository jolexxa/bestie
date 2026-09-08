import 'package:intentions/intentions.dart';

@model
sealed class ConfigOutput {
  const ConfigOutput();
}

@model
final class ConfigStateUpdated extends ConfigOutput {
  const ConfigStateUpdated();
}

@model
final class CloseRequested extends ConfigOutput {
  const CloseRequested();
}

/// The row selection moved to [index] within the current page. The view
/// subscribes and calls `ensureIndexVisible` on its scroll controller.
@model
final class CursorMoved extends ConfigOutput {
  const CursorMoved(this.index);
  final int index;
}

/// The selected page changed. The view subscribes and resets its scroll
/// controller to the top.
@model
final class PageChanged extends ConfigOutput {
  const PageChanged();
}
