import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';

@model
sealed class ConfigInput {
  const ConfigInput();
}

@model
final class Initialize extends ConfigInput {
  Initialize({required this.targetScope, required this.toolCount});
  final ConfigScope? targetScope;
  final int toolCount;
}

@model
final class MoveSelection extends ConfigInput {
  const MoveSelection(this.delta);
  final int delta;
}

@model
final class ChangePage extends ConfigInput {
  const ChangePage(this.delta);
  final int delta;
}

@model
final class InlineAdjust extends ConfigInput {
  const InlineAdjust(this.delta);
  final int delta;
}

@model
final class BeginEdit extends ConfigInput {
  const BeginEdit();
}

@model
final class ResetParam extends ConfigInput {
  const ResetParam();
}

@model
final class ConfirmEdit extends ConfigInput {
  const ConfirmEdit(this.text);
  final String text;
}

@model
final class CancelEdit extends ConfigInput {
  const CancelEdit();
}

@model
final class RequestClose extends ConfigInput {
  const RequestClose();
}

@model
final class ConfigChanged extends ConfigInput {
  const ConfigChanged();
}
