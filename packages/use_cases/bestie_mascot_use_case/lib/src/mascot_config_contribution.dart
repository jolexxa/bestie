import 'package:bestie_mascot_use_case/src/mascot.dart';
import 'package:bestie_mascot_use_case/src/mascot_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class MascotConfigContribution implements ConfigContribution {
  MascotConfigContribution() : configKeys = MascotConfigKeys.defaults();

  final MascotConfigKeys configKeys;

  @override
  Iterable<ConfigEntry> get entries => [
    globalEntry(
      key: configKeys.mascot,
      field: EnumField<String>(
        label: 'Mascot',
        description: 'The mascot that lives in the corner of the app.',
        options: () => [for (final mascot in Mascot.values) mascot.id],
        optionLabel: (id) => Mascot.parse(id).label,
      ),
    ),
  ];
}
