import 'package:config_protocol/src/config_entry.dart';

/// A feature's self-owned configuration UI, collected at the composition root
/// the same way tool responders are.
abstract interface class ConfigContribution {
  /// Key-to-field bindings the config UI renders for this feature.
  Iterable<ConfigEntry> get entries;
}
