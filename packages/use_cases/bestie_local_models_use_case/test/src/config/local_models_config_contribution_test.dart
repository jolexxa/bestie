import 'package:bestie_local_models_use_case/bestie_local_models_use_case.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('models.paths lists folders and defaults to none', () {
    final keys = LocalModelsConfigKeys.defaults();
    expect(keys.paths.id, 'models.paths');
    expect(keys.paths.path, ['models', 'paths']);
    expect(keys.paths.defaultValue(), isEmpty);
  });

  test('contributes the model folders as a global list field', () {
    final contribution = LocalModelsConfigContribution();
    final entries = contribution.entries.toList();
    expect(entries, hasLength(1));
    expect(entries.single.key, same(contribution.configKeys.paths));
    expect(entries.single.field, isA<ListField>());
    expect((entries.single.field as ListField).label, 'Model folders');
  });
}
