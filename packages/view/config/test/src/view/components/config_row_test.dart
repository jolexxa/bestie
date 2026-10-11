import 'package:bestie_config_view/src/view/components/config_row.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:config_repository/config_repository.dart';
import 'package:config_repository/testing.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

double _defaultTemperature() => 0.7;

ConfigKey<double> _temperature({
  String? unsetLabel,
  ConfigResolution<double> resolution = const ConfigResolution.exact(),
}) => ConfigKey<double>(
  id: 'provider.sampling.temperature',
  path: const ['provider', 'sampling', 'temperature'],
  codec: ConfigCodecs.doubles,
  defaultValue: _defaultTemperature,
  resolution: resolution,
  field: NumericField<double>(
    label: 'Temperature',
    description: 'randomness',
    min: 0,
    max: 2,
    step: 0.1,
    unsetLabel: unsetLabel,
  ),
);

final _qwen = ConfigScope.path(const ['models', 'qwen']);

Component _row(ConfigAddressBase address, ConfigView resolver) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: ConfigRow(
      address: address,
      resolver: resolver,
      isSelected: false,
      isEditing: false,
    ),
  ),
);

Future<void> _render(
  ConfigAddressBase address,
  ConfigView resolver,
  void Function(TerminalState screen) check,
) => testNocterm('config row', (tester) async {
  await tester.pumpComponent(_row(address, resolver));
  check(tester.terminalState);
}, size: const Size(60, 4));

void main() {
  test('shows the unset label while nobody has chosen a value', () async {
    await _render(
      _temperature(unsetLabel: 'model default').global,
      FakeConfigRepository(),
      (screen) {
        expect(screen, containsText('model default'));
        expect(screen, isNot(containsText('0.7')));
      },
    );
  });

  test('shows the chosen value over the unset label', () async {
    await _render(
      _temperature(unsetLabel: 'model default').global,
      FakeConfigRepository({'provider.sampling.temperature': 0.3}),
      (screen) {
        expect(screen, containsText('0.3'));
        expect(screen, containsText('set'));
        expect(screen, isNot(containsText('model default')));
      },
    );
  });

  test('shows the default when the field has no unset label', () async {
    await _render(
      _temperature().global,
      FakeConfigRepository(),
      (screen) => expect(screen, containsText('0.7')),
    );
  });

  test('marks a value a scope inherits from its parent', () async {
    final key = _temperature(resolution: const ConfigResolution.scoped());

    await _render(
      key.at(_qwen),
      FakeConfigRepository({'provider.sampling.temperature': 0.3}),
      (screen) {
        expect(screen, containsText('0.3'));
        expect(screen, containsText('inherited'));
      },
    );
  });
}
