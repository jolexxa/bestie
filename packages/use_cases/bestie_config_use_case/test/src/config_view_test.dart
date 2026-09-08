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

void main() {
  late Directory tmp;
  late ConfigRepository repo;
  late ConfigUseCase useCase;

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cow_config_view_test_');
    repo = ConfigRepository(
      dataSource: ConfigDataSource(configFile: '${tmp.path}/bestie.json')
        ..load(),
    );
    useCase = ConfigUseCase(repo);
  });

  tearDown(() async {
    await useCase.dispose();
    tmp.deleteSync(recursive: true);
  });

  group('a use case with no session reads through to the repository', () {
    test('reports the default value and no source', () {
      expect(useCase.resolve(_primaryCap.global), 0);
      expect(useCase.resolveBase(_primaryCap.global), 0);
      expect(useCase.inspect(_primaryCap.global).isDefault, isTrue);
      expect(useCase.inspectBase(_primaryCap.global).isDefault, isTrue);
      expect(useCase.isExplicit(_primaryCap.global), isFalse);
      expect(useCase.isExplicitBase(_primaryCap.global), isFalse);
      expect(useCase.defines(_primaryCap.global), isFalse);
      expect(useCase.definesBase(_primaryCap.global), isFalse);
    });

    test('reports a committed value and where it came from', () async {
      useCase.update(_primaryCap.global, const ConfigEdit.set(8192));
      await pump();

      expect(useCase.resolve(_primaryCap.global), 8192);
      expect(useCase.resolveBase(_primaryCap.global), 8192);
      expect(useCase.inspect(_primaryCap.global).source, _primaryCap.global);
      expect(
        useCase.inspectBase(_primaryCap.global).source,
        _primaryCap.global,
      );
      expect(useCase.isExplicit(_primaryCap.global), isTrue);
      expect(useCase.isExplicitBase(_primaryCap.global), isTrue);
      expect(useCase.defines(_primaryCap.global), isTrue);
      expect(useCase.definesBase(_primaryCap.global), isTrue);
    });

    test('streams changes and watches a single address', () async {
      final changes = <ConfigChange>[];
      final watched = <int>[];
      final changesSub = useCase.changes.listen(changes.add);
      final watchSub = useCase.watch(_primaryCap.global).listen(watched.add);
      addTearDown(changesSub.cancel);
      addTearDown(watchSub.cancel);

      useCase.update(_primaryCap.global, const ConfigEdit.set(8192));
      await pump();

      expect(changes.single.keyIds, {'runtime.primary_context_cap'});
      expect(watched, [0, 8192]);
    });
  });

  group('an open session shadows the repository', () {
    test('staged edits are visible through every read', () async {
      useCase
        ..beginSession()
        ..update(_primaryCap.global, const ConfigEdit.set(4096));
      await pump();

      expect(useCase.resolve(_primaryCap.global), 4096);
      expect(useCase.resolveBase(_primaryCap.global), 4096);
      expect(useCase.inspect(_primaryCap.global).value, 4096);
      expect(useCase.inspectBase(_primaryCap.global).value, 4096);
      expect(useCase.isExplicit(_primaryCap.global), isTrue);
      expect(useCase.isExplicitBase(_primaryCap.global), isTrue);
      expect(useCase.defines(_primaryCap.global), isTrue);
      expect(useCase.definesBase(_primaryCap.global), isTrue);
    });
  });

  group('a session used on its own', () {
    test('stages a typed edit and reads it back', () {
      final session = ConfigSession(repo)
        ..update(_primaryCap.global, const ConfigEdit.set(2048));

      expect(session.edits, {_primaryCap.global: const ConfigEdit.set(2048)});
      expect(session.resolve(_primaryCap.global), 2048);
      expect(session.resolveBase(_primaryCap.global), 2048);
      expect(session.inspect(_primaryCap.global).value, 2048);
      expect(session.inspectBase(_primaryCap.global).value, 2048);
      expect(session.isExplicit(_primaryCap.global), isTrue);
      expect(session.isExplicitBase(_primaryCap.global), isTrue);
      expect(session.defines(_primaryCap.global), isTrue);
      expect(session.definesBase(_primaryCap.global), isTrue);
    });
  });
}
