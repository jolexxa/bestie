import 'package:bestie_config/bestie_config.dart';
import 'package:config_repository/config_repository.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigRepository', () {
    late ConfigDataSource store;
    late ConfigRepository repo;
    late _Keys keys;

    setUp(() {
      store = ConfigDataSource(configFile: '')..load();
      keys = _Keys();
      repo = ConfigRepository(dataSource: store);
    });

    tearDown(() => repo.dispose());

    test('global addresses resolve key defaults and committed overrides', () {
      final theme = keys.theme.global;

      expect(repo.inspect(theme).value, 'cow');
      expect(repo.inspect(theme).source, isNull);
      expect(repo.isExplicit(theme), isFalse);

      repo.commit({theme: const ConfigEdit.set('matrix')});

      expect(repo.inspect(theme).value, 'matrix');
      expect(repo.inspect(theme).source, theme);
      expect(repo.isExplicit(theme), isTrue);
      expect(store.user.read(['app', 'themeName']), 'matrix');
    });

    test('pinning a default emits because source changed', () async {
      final theme = keys.theme.global;
      final changes = <ConfigChange>[];
      final sub = repo.changes.listen(changes.add);

      repo.commit({theme: const ConfigEdit.set('cow')});
      await pumpEventQueue();

      expect(changes.single.contains(theme), isTrue);
      expect(repo.inspect(theme).source, theme);
      await sub.cancel();
    });

    test('user values resolve before scope defaults', () {
      final sampling = keys.samplingTemperature.at(_modelScope('qwen'));
      store.user.write(sampling.path, 0.9);
      repo.applyScopeDefaults({sampling: 0.2});

      final resolved = repo.inspect(sampling);

      expect(resolved.value, 0.9);
      expect(resolved.source, sampling);
      expect(repo.isExplicit(sampling), isTrue);
      expect(repo.defines(sampling), isTrue);
    });

    test('model scoped values resolve from scope defaults', () {
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      repo.applyScopeDefaults({reasoning: 0.4});

      final resolved = repo.inspect(reasoning);

      expect(resolved.value, 0.4);
      expect(resolved.source, reasoning);
      expect(repo.isExplicit(reasoning), isFalse);
      expect(repo.defines(reasoning), isTrue);
    });

    test('republishing announces the addresses that moved', () async {
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      final settled = keys.samplingTemperature.at(_modelScope('qwen'));
      repo.applyScopeDefaults({reasoning: 0.4, settled: 0.5});
      final changes = <ConfigChange>[];
      final sub = repo.changes.listen(changes.add);

      repo.applyScopeDefaults({reasoning: 0.6, settled: 0.5});
      await pumpEventQueue();

      expect(changes.single.contains(reasoning), isTrue);
      expect(changes.single.contains(settled), isFalse);
      await sub.cancel();
    });

    test('scope defaults that disappear fall back to the key default', () {
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      repo.applyScopeDefaults({reasoning: 0.4});
      expect(repo.defines(reasoning), isTrue);

      repo.applyScopeDefaults(const {});

      expect(
        repo.inspect(reasoning).value,
        keys.reasoningTemperature.defaultValue(),
      );
      expect(repo.defines(reasoning), isFalse);
    });

    test('key fallbacks borrow values without making the address explicit', () {
      final sampling = keys.samplingTemperature.at(_modelScope('qwen'));
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      store.user.write(sampling.path, 0.9);

      final resolved = repo.inspect(reasoning);

      expect(resolved.value, 0.9);
      expect(resolved.source, sampling);
      expect(repo.isExplicit(reasoning), isFalse);
      expect(repo.defines(reasoning), isFalse);
    });

    test('preview set composes with committed user layer', () {
      final sampling = keys.samplingTemperature.at(_modelScope('qwen'));
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      store.user
        ..write(sampling.path, 0.7)
        ..write(reasoning.path, 0.6);

      final resolved = repo
          .view(
            edits: {
              sampling: const ConfigEdit.set(0.9),
            },
          )
          .inspect(reasoning);

      expect(resolved.value, 0.6);
      expect(resolved.source, reasoning);
    });

    test('preview clear removes only that address for resolution', () {
      final sampling = keys.samplingTemperature.at(_modelScope('qwen'));
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      store.user
        ..write(sampling.path, 0.7)
        ..write(reasoning.path, 0.6);

      final resolved = repo
          .view(
            edits: {
              reasoning: const ConfigEdit<double>.clear(),
            },
          )
          .inspect(reasoning);

      expect(resolved.value, 0.7);
      expect(resolved.source, sampling);
    });

    test('commit clears committed user values and emits once', () async {
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      store.user.write(reasoning.path, 0.6);
      final changes = <ConfigChange>[];
      final sub = repo.changes.listen(changes.add);

      repo.commit({reasoning: const ConfigEdit<double>.clear()});
      await pumpEventQueue();

      expect(store.user.read(reasoning.path), isNull);
      expect(changes.single.contains(reasoning), isTrue);
      expect(repo.inspect(reasoning).value, 0.7);
      expect(repo.inspect(reasoning).source, isNull);
      await sub.cancel();
    });

    test('scope ancestry resolves parent scope values', () {
      final sampling = keys.samplingTemperature.at(_modelScope('qwen'));
      final profile = _modelScope('qwen').child(_profileScope('creative'));
      final reasoning = keys.reasoningTemperature.at(profile);
      store.user.write(sampling.path, 0.3);

      final resolved = repo.inspect(reasoning);

      expect(resolved.value, 0.3);
      expect(resolved.source, sampling);
    });

    test('live edits take effect without touching persisted JSON', () async {
      final theme = keys.theme.global;
      final changes = <ConfigChange>[];
      final sub = repo.changes.listen(changes.add);

      repo.applyLive({theme: const ConfigEdit.set('matrix')});
      await pumpEventQueue();

      expect(repo.resolve(theme), 'matrix');
      expect(store.user.read(theme.path), isNull);
      expect(changes.single.contains(theme), isTrue);
      expect(repo.isExplicit(theme), isTrue);
      await sub.cancel();
    });

    test('commit persists a live edit and removes the live shadow', () {
      final theme = keys.theme.global;

      repo
        ..applyLive({theme: const ConfigEdit.set('matrix')})
        ..commit({theme: const ConfigEdit.set('matrix')});

      expect(repo.resolve(theme), 'matrix');
      expect(store.user.read(theme.path), 'matrix');
    });

    test('watch re-emits when a fallback address changes', () async {
      final reasoning = keys.reasoningTemperature.at(_modelScope('qwen'));
      final sampling = keys.samplingTemperature.at(_modelScope('qwen'));
      final values = repo.watch(reasoning).take(2).toList();
      await pumpEventQueue();

      repo.commit({sampling: const ConfigEdit.set(0.2)});

      await expectLater(values, completion([0.7, 0.2]));
    });

    test(
      'watch emits initial value and then distinct resolved values',
      () async {
        final theme = keys.theme.global;
        final values = repo.watch(theme).take(2).toList();
        await pumpEventQueue();

        repo
          ..commit({theme: const ConfigEdit.set('cow')})
          ..commit({theme: const ConfigEdit.set('dark')});

        await expectLater(values, completion(['cow', 'dark']));
      },
    );
  });
}

final class _Keys {
  final assignment = ConfigKey<String>(
    id: 'assignment',
    path: const ['model'],
    codec: ConfigCodecs.strings,
    defaultValue: () => '',
  );

  final theme = ConfigKey<String>(
    id: 'app.theme',
    path: const ['app', 'themeName'],
    codec: ConfigCodecs.strings,
    defaultValue: () => 'cow',
  );

  late final samplingTemperature = ConfigKey<double>(
    id: 'sampling.temperature',
    path: const ['runtimeConfig', 'temperature'],
    codec: ConfigCodecs.doubles,
    defaultValue: () => 0.7,
    resolution: const ConfigResolution.scoped(),
  );

  late final reasoningTemperature = ConfigKey<double>(
    id: 'reasoning.temperature',
    path: const ['reasoningConfig', 'temperature'],
    codec: ConfigCodecs.doubles,
    defaultValue: () => 0.7,
    resolution: ConfigResolution.scoped(fallbackKeys: [samplingTemperature]),
  );
}

ConfigScope _modelScope(String modelId) =>
    ConfigScope.path(['models', modelId]);

ConfigScope _profileScope(String profileId) =>
    ConfigScope.path(['profiles', profileId]);
