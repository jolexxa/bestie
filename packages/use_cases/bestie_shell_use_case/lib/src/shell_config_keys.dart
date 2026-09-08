import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

const defaultShellScrollbackMb = 32;

@model
final class ShellConfigKeys {
  const ShellConfigKeys({required this.scrollbackMb});

  factory ShellConfigKeys.defaults() => ShellConfigKeys(
    scrollbackMb: ConfigKey<int>(
      id: 'app.shell_scrollback_mb',
      path: const ['app', 'shellScrollbackMb'],
      codec: ConfigCodecs.integers,
      defaultValue: () => defaultShellScrollbackMb,
    ),
  );

  final ConfigKey<int> scrollbackMb;
}
