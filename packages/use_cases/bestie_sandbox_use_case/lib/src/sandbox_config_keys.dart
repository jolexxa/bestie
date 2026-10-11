import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:sandbox/sandbox.dart';

const networkTierCodec = ConfigCodec<NetworkTier>(
  decode: _decodeNetworkTier,
  encode: _encodeNetworkTier,
);

NetworkTier? _decodeNetworkTier(Object? raw) =>
    raw is String ? NetworkTier.values.asNameMap()[raw] : null;

Object? _encodeNetworkTier(NetworkTier? tier) => tier?.name;

@model
final class SandboxConfigKeys {
  const SandboxConfigKeys({
    required this.sandboxAgentShell,
    required this.sandboxFailClosed,
    required this.sandboxNetworkTier,
    required this.sandboxWriteGrants,
  });

  factory SandboxConfigKeys.defaults() => SandboxConfigKeys(
    sandboxAgentShell: ConfigKey<bool>(
      id: 'app.sandbox_agent_shell',
      path: const ['app', 'sandboxAgentShell'],
      codec: ConfigCodecs.booleans,
      defaultValue: () => true,
      field: const BoolField(
        label: 'Confine Commands',
        description:
            "Run the agent's shell commands and edits inside the host OS "
            'sandbox. Takes effect on the next launch.',
      ),
    ),
    sandboxFailClosed: ConfigKey<bool>(
      id: 'app.sandbox_fail_closed',
      path: const ['app', 'sandboxFailClosed'],
      codec: ConfigCodecs.booleans,
      defaultValue: () => true,
      field: const BoolField(
        label: 'Fail Closed',
        description:
            'When confinement cannot be acquired, refuse the command '
            'rather than running it unconfined.',
      ),
    ),
    sandboxNetworkTier: ConfigKey<NetworkTier>(
      id: 'app.sandbox_network_tier',
      path: const ['app', 'sandboxNetworkTier'],
      codec: networkTierCodec,
      defaultValue: () => NetworkTier.all,
      field: EnumField(
        label: 'Network Access',
        description:
            "What the agent's commands may reach. Loopback allows "
            'localhost only; unrestricted is the default.',
        options: () => NetworkTier.values,
        optionLabel: _networkTierLabel,
      ),
    ),
    sandboxWriteGrants: ConfigKey<List<String>>(
      id: 'app.sandbox_write_grants',
      path: const ['app', 'sandboxWriteGrants'],
      codec: ConfigCodecs.stringLists,
      defaultValue: () => const [],
      field: const ListField(
        label: 'Write Grants',
        description:
            'Folders beyond the workspace the agent may write to, one per '
            'line.',
      ),
    ),
  );

  /// Whether the agent's programs run confined by the host sandbox.
  final ConfigKey<bool> sandboxAgentShell;

  /// Whether a supported sandbox that cannot be acquired refuses the program
  /// rather than running it unconfined.
  final ConfigKey<bool> sandboxFailClosed;

  /// The network tier the agent's programs run under.
  final ConfigKey<NetworkTier> sandboxNetworkTier;

  /// Directories beyond the workspace the user has allowed the agent's
  /// programs to write to, kept out of the config overlay.
  final ConfigKey<List<String>> sandboxWriteGrants;
}

String _networkTierLabel(NetworkTier tier) => switch (tier) {
  NetworkTier.local => 'Loopback only',
  NetworkTier.none => 'No network',
  NetworkTier.all => 'Unrestricted',
};
