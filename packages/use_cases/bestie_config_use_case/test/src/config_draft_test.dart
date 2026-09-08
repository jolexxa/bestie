import 'dart:async';
import 'dart:io';

import 'package:bestie_config/bestie_config.dart';
import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:config_repository/config_repository.dart';
import 'package:test/test.dart';

final _primaryCap = ConfigKey<int>(
  id: 'runtime.primary_context_cap',
  path: const ['runtime', 'primaryContextCap'],
  codec: ConfigCodecs.integers,
  defaultValue: () => 0,
  effect: ConfigEffect.onCommit,
);

final _compactionRatio = ConfigKey<double>(
  id: 'memory.compaction_ratio',
  path: const ['compaction', 'compactionRatio'],
  codec: ConfigCodecs.doubles,
  defaultValue: () => 0.6,
  effect: ConfigEffect.onCommit,
);

final _themeEffects = ConfigKey<bool>(
  id: 'app.theme_effects',
  path: const ['app', 'themeEffects'],
  codec: ConfigCodecs.booleans,
  defaultValue: () => true,
);

void main() {
  late Directory tmp;
  late ConfigDataSource store;
  late ConfigRepository repo;
  late ConfigUseCase useCase;
  late List<ConfigChange> changes;

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cow_config_draft_test_');
    store = ConfigDataSource(configFile: '${tmp.path}/bestie.json')..load();
    repo = ConfigRepository(dataSource: store);
    useCase = ConfigUseCase(repo);
    changes = [];
    final sub = repo.changes.listen(changes.add);
    addTearDown(sub.cancel);
  });

  tearDown(() async {
    await useCase.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('deferred write stages during a session, commits on close', () async {
    useCase
      ..beginSession()
      ..update(_primaryCap.global, const ConfigEdit.set(8192));
    await pump();

    expect(store.user.read(['runtime', 'primaryContextCap']), isNull);
    expect(changes, isEmpty);
    expect(useCase.resolve(_primaryCap.global), 8192);

    useCase.endSession();
    await pump();

    expect(store.user.read(['runtime', 'primaryContextCap']), 8192);
    expect(changes.single.keyIds, {'runtime.primary_context_cap'});
  });

  test('live write applies during a session and persists on close', () async {
    useCase
      ..beginSession()
      ..update(_themeEffects.global, const ConfigEdit.set(false));
    await pump();

    expect(useCase.resolve(_themeEffects.global), isFalse);
    expect(store.user.read(['app', 'themeEffects']), isNull);
    expect(changes.single.keyIds, {'app.theme_effects'});

    useCase.endSession();
    expect(store.user.read(['app', 'themeEffects']), isFalse);
  });

  test('net-zero deferred round-trip commits nothing', () async {
    useCase.update(_primaryCap.global, const ConfigEdit.set(4096));
    await pump();
    changes.clear();

    useCase
      ..beginSession()
      ..update(_primaryCap.global, const ConfigEdit.set(8192))
      ..update(_primaryCap.global, const ConfigEdit.set(4096))
      ..endSession();
    await pump();

    expect(store.user.read(['runtime', 'primaryContextCap']), 4096);
    expect(changes, isEmpty);
  });

  test('cancelSession discards staged edits', () async {
    useCase
      ..beginSession()
      ..update(_primaryCap.global, const ConfigEdit.set(8192))
      ..cancelSession();
    await pump();

    expect(store.user.read(['runtime', 'primaryContextCap']), isNull);
    expect(changes, isEmpty);
  });

  test('cancelSession keeps live values but does not persist them', () async {
    useCase
      ..beginSession()
      ..update(_themeEffects.global, const ConfigEdit.set(false))
      ..cancelSession();
    await pump();

    expect(useCase.resolve(_themeEffects.global), isFalse);
    expect(store.user.read(['app', 'themeEffects']), isNull);
  });

  test('multiple deferred edits apply as a single change', () async {
    useCase
      ..beginSession()
      ..update(_primaryCap.global, const ConfigEdit.set(8192))
      ..update(_compactionRatio.global, const ConfigEdit.set(0.75));
    await pump();
    expect(changes, isEmpty);

    useCase.endSession();
    await pump();

    expect(changes.single.keyIds, {
      'runtime.primary_context_cap',
      'memory.compaction_ratio',
    });
  });

  test('deferred write outside a session applies immediately', () async {
    useCase.update(_primaryCap.global, const ConfigEdit.set(8192));
    await pump();

    expect(store.user.read(['runtime', 'primaryContextCap']), 8192);
    expect(changes.single.keyIds, {'runtime.primary_context_cap'});
  });
}
