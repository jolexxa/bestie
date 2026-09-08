import 'package:bestie_shell_use_case/src/shell_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

/// The shell's keys. None is offered in the overlay: scrollback is a
/// hand-edited value.
@model
final class ShellConfigContribution implements ConfigContribution {
  ShellConfigContribution() : configKeys = ShellConfigKeys.defaults();

  final ShellConfigKeys configKeys;

  @override
  Iterable<ConfigEntry> get entries => const [];
}
