import 'package:bestie_sandbox_use_case/src/sandbox_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:sandbox/sandbox.dart';

@model
final class SandboxConfigContribution implements ConfigContribution {
  SandboxConfigContribution() : configKeys = SandboxConfigKeys.defaults();

  final SandboxConfigKeys configKeys;

  @override
  Iterable<ConfigEntry> get entries => [
    globalEntry(
      key: configKeys.sandboxAgentShell,
      field: BoolField(
        label: 'Confine Commands',
        description:
            "Run the agent's shell commands and edits inside the host OS "
            'sandbox. Takes effect on the next launch.',
      ),
    ),
    globalEntry(
      key: configKeys.sandboxFailClosed,
      field: BoolField(
        label: 'Fail Closed',
        description:
            'When confinement cannot be acquired, refuse the command '
            'rather than running it unconfined.',
      ),
    ),
    globalEntry(
      key: configKeys.sandboxNetworkTier,
      field: EnumField<NetworkTier>(
        label: 'Network Access',
        description:
            "What the agent's commands may reach. Loopback allows "
            'localhost only; unrestricted is the default.',
        options: () => NetworkTier.values,
        optionLabel: _networkTierLabel,
      ),
    ),
  ];
}

String _networkTierLabel(NetworkTier tier) => switch (tier) {
  NetworkTier.local => 'Loopback only',
  NetworkTier.none => 'No network',
  NetworkTier.all => 'Unrestricted',
};
