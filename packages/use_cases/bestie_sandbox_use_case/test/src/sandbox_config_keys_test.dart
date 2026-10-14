import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:sandbox/sandbox.dart';
import 'package:test/test.dart';

void main() {
  final keys = SandboxConfigKeys.defaults();

  test('keys default to confined, fail-closed, and unrestricted network', () {
    expect(keys.sandboxAgentShell.defaultValue(), isTrue);
    expect(keys.sandboxFailClosed.defaultValue(), isTrue);
    expect(keys.sandboxNetworkTier.defaultValue(), NetworkTier.all);
    expect(keys.sandboxWriteGrants.defaultValue(), isEmpty);
  });

  test('shows the switches as toggles and the tier as a choice', () {
    expect(keys.sandboxAgentShell.field, isA<BoolField>());
    expect(keys.sandboxFailClosed.field, isA<BoolField>());
    expect(keys.sandboxNetworkTier.field, isA<EnumField<NetworkTier>>());
    expect(keys.sandboxWriteGrants.field, isA<ListField>());
  });

  test('names every network tier for the overlay', () {
    final field = keys.sandboxNetworkTier.field as EnumField<NetworkTier>;

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
