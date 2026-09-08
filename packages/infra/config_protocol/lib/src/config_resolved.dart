import 'package:config_protocol/src/config_key.dart';

final class Resolved<T> {
  const Resolved({
    required this.value,
    required this.source,
  });

  final T value;
  final ConfigAddressBase? source;

  bool inheritedInto(ConfigAddressBase own) => source != null && source != own;

  bool get isDefault => source == null;
}
