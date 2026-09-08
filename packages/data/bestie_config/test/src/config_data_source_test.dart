import 'dart:convert';
import 'dart:io';

import 'package:bestie_config/bestie_config.dart';
import 'package:test/test.dart';

void main() {
  group('ConfigDataSource', () {
    late Directory tmp;
    late File configFile;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync(
        'bestie_config_data_source_test_',
      );
      configFile = File('${tmp.path}/bestie.json');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('starts fresh when the file is missing', () {
      final store = ConfigDataSource(configFile: configFile.path);

      expect(store.load(), isA<ConfigStartedFresh>());
      expect(store.user.isEmpty, isTrue);
    });

    test('starts fresh when the file is empty', () {
      configFile.writeAsStringSync('  \n');
      final store = ConfigDataSource(configFile: configFile.path);

      expect(store.load(), isA<ConfigStartedFresh>());
      expect(store.user.isEmpty, isTrue);
    });

    test('loads an existing JSON object into the user layer', () {
      configFile.writeAsStringSync(
        jsonEncode({
          'runtime': {'primaryContextCap': 8192},
        }),
      );
      final store = ConfigDataSource(configFile: configFile.path);

      expect(store.load(), isA<ConfigLoaded>());
      expect(store.user.read(['runtime', 'primaryContextCap']), 8192);
    });

    test('persists with a temp-file rename and creates parent dirs', () {
      final nested = File('${tmp.path}/nested/bestie.json');
      ConfigDataSource(configFile: nested.path)
        ..load()
        ..user.write(['app', 'themeEffects'], false)
        ..persist();

      expect(nested.existsSync(), isTrue);
      expect(File('${nested.path}.tmp').existsSync(), isFalse);
      expect(jsonDecode(nested.readAsStringSync()), {
        'app': {'themeEffects': false},
      });
    });

    test('renames corrupt JSON aside and starts fresh', () {
      configFile.writeAsStringSync('{ nope');
      final store = ConfigDataSource(configFile: configFile.path);

      final result = store.load();

      expect(result, isA<ConfigRecovered>());
      final backupPath = (result as ConfigRecovered).backupPath;
      expect(File(backupPath).readAsStringSync(), '{ nope');
      expect(configFile.existsSync(), isFalse);
      expect(store.user.isEmpty, isTrue);
    });

    test('does not overwrite an existing corrupt backup', () {
      configFile.writeAsStringSync('[]');
      File('${configFile.path}.bak').writeAsStringSync('first');
      final store = ConfigDataSource(configFile: configFile.path);

      final result = store.load() as ConfigRecovered;

      expect(result.backupPath, '${configFile.path}.bak.1');
      expect(File('${configFile.path}.bak').readAsStringSync(), 'first');
      expect(File(result.backupPath).readAsStringSync(), '[]');
    });

    test('numbers each corrupt backup past the first', () {
      configFile.writeAsStringSync('[]');
      File('${configFile.path}.bak').writeAsStringSync('first');
      File('${configFile.path}.bak.1').writeAsStringSync('second');
      final store = ConfigDataSource(configFile: configFile.path);

      final result = store.load() as ConfigRecovered;

      expect(result.backupPath, '${configFile.path}.bak.2');
      expect(File(result.backupPath).readAsStringSync(), '[]');
    });

    test('empty path is an in-memory seam', () {
      final store = ConfigDataSource(configFile: '')
        ..load()
        ..user.write(['app', 'themeName'], 'cow')
        ..persist();

      expect(store.user.read(['app', 'themeName']), 'cow');
    });
  });
}
