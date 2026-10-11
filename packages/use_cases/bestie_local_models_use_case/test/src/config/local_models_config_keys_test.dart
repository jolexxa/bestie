import 'package:bestie_local_models_use_case/bestie_local_models_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('models.paths lists folders and defaults to none', () {
    final keys = LocalModelsConfigKeys.defaults();

    expect(keys.paths.id, 'models.paths');
    expect(keys.paths.path, ['models', 'paths']);
    expect(keys.paths.defaultValue(), isEmpty);
    expect(keys.paths.field, isA<ListField>());
    expect(keys.paths.field.label, 'Model folders');
  });
}
