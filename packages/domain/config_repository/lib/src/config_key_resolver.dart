import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
abstract interface class ConfigKeyResolver {
  Resolved<Object?> inspectBase(ConfigAddressBase address);

  Resolved<T> inspect<T>(ConfigAddress<T> address);

  Object? resolveBase(ConfigAddressBase address);

  T resolve<T>(ConfigAddress<T> address);
}

@model
abstract interface class ConfigView implements ConfigKeyResolver {
  bool isExplicitBase(ConfigAddressBase address);

  bool isExplicit<T>(ConfigAddress<T> address);

  bool definesBase(ConfigAddressBase address);

  bool defines<T>(ConfigAddress<T> address);
}
