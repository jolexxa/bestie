import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:sandbox/sandbox.dart';
import 'package:test/test.dart';

void main() {
  final contribution = SandboxConfigContribution();
  final keys = contribution.configKeys;

  test('keys default to confined, fail-closed, and unrestricted network', () {
    expect(keys.sandboxAgentShell.defaultValue(), isTrue);
    expect(keys.sandboxFailClosed.defaultValue(), isTrue);
    expect(keys.sandboxNetworkTier.defaultValue(), NetworkTier.all);
  });

  test('contributes one global entry per key', () {
    final entries = contribution.entries.toList();

    expect(entries.map((entry) => entry.key.id), [
      'app.sandbox_agent_shell',
      'app.sandbox_fail_closed',
      'app.sandbox_network_tier',
    ]);
    expect(entries[0].field, isA<BoolField>());
    expect(entries[1].field, isA<BoolField>());
    expect(entries[2].field, isA<EnumField<NetworkTier>>());
  });

  test('names every network tier for the overlay', () {
    final field = contribution.entries.last.field as EnumField<NetworkTier>;

    expect(field.options(), NetworkTier.values);
    expect(field.optionLabel(NetworkTier.all), 'Unrestricted');
    expect(field.optionLabel(NetworkTier.local), 'Loopback only');
    expect(field.optionLabel(NetworkTier.none), 'No network');
  });

  test('round-trips a network tier through its codec by name', () {
    expect(networkTierCodec.encode(NetworkTier.local), 'local');
    expect(networkTierCodec.decode('none'), NetworkTier.none);
    expect(networkTierCodec.decode('nonsense'), isNull);
    expect(networkTierCodec.decode(42), isNull);
    expect(networkTierCodec.encode(null), isNull);
  });
}
