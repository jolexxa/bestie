import 'package:config_protocol/src/config_key.dart';

final class ConfigChange {
  ConfigChange(Iterable<ConfigAddressBase> addresses)
    : addresses = Set.unmodifiable(addresses),
      keyIds = {for (final address in addresses) address.key.id};

  const ConfigChange.ids({
    required this.keyIds,
    this.addresses = const {},
  });

  final Set<ConfigAddressBase> addresses;
  final Set<String> keyIds;

  bool contains(ConfigAddressBase address) => addresses.contains(address);

  bool containsKey(ConfigKeyBase key) => keyIds.contains(key.id);

  bool get isEmpty => addresses.isEmpty && keyIds.isEmpty;
}
