import 'package:bestie_config_view/src/view/components/config_row.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:config_repository/config_repository.dart';
import 'package:config_repository/testing.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

const _temperature = ConfigKey<double>(
  id: 'provider.sampling.temperature',
  path: ['provider', 'sampling', 'temperature'],
  codec: ConfigCodecs.doubles,
  defaultValue: _defaultTemperature,
);

double _defaultTemperature() => 0.7;

NumericField<double> _field({String? unsetLabel}) => NumericField<double>(
  label: 'Temperature',
  description: 'randomness',
  min: 0,
  max: 2,
  step: 0.1,
  unsetLabel: unsetLabel,
);

Component _row(ConfigEntry entry, ConfigView resolver) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(
    data: appThemeDefault,
    child: ConfigRow(
      entry: entry,
      resolver: resolver,
      targetScope: null,
      isSelected: false,
      isEditing: false,
    ),
  ),
);

Future<void> _render(
  ConfigEntry entry,
  ConfigView resolver,
  void Function(TerminalState screen) check,
) => testNocterm('config row', (tester) async {
  await tester.pumpComponent(_row(entry, resolver));
  check(tester.terminalState);
}, size: const Size(60, 4));

void main() {
  test('shows the unset label while nobody has chosen a value', () async {
    await _render(
      globalEntry(
        key: _temperature,
        field: _field(unsetLabel: 'model default'),
      ),
      FakeConfigRepository(),
      (screen) {
        expect(screen, containsText('model default'));
        expect(screen, isNot(containsText('0.7')));
      },
    );
  });

  test('shows the chosen value over the unset label', () async {
    await _render(
      globalEntry(
        key: _temperature,
        field: _field(unsetLabel: 'model default'),
      ),
      FakeConfigRepository({'provider.sampling.temperature': 0.3}),
      (screen) {
        expect(screen, containsText('0.3'));
        expect(screen, isNot(containsText('model default')));
      },
    );
  });

  test('shows the default when the field has no unset label', () async {
    await _render(
      globalEntry(key: _temperature, field: _field()),
      FakeConfigRepository(),
      (screen) => expect(screen, containsText('0.7')),
    );
  });
}
