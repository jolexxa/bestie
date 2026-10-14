import 'package:bestie_mascot_use_case/src/mascot.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class MascotConfigKeys {
  const MascotConfigKeys({required this.mascot});

  factory MascotConfigKeys.defaults() => MascotConfigKeys(
    mascot: ConfigKey<String>(
      id: 'app.mascot',
      path: const ['app', 'mascot'],
      codec: ConfigCodecs.strings,
      defaultValue: () => Mascot.cow.id,
      field: EnumField(
        label: 'Mascot',
        description: 'The mascot that lives in the corner of the app.',
        options: () => [for (final mascot in Mascot.values) mascot.id],
        optionLabel: (id) => Mascot.parse(id).label,
      ),
    ),
  );

  final ConfigKey<String> mascot;
}
