import 'dart:convert';
import 'dart:io';

import 'package:bestie_config/src/config_layer.dart';
import 'package:bestie_config/src/config_load_result.dart';
import 'package:intentions/intentions.dart';

@dataSource
class ConfigDataSource {
  ConfigDataSource({required String configFile}) : _configFile = configFile;

  final String _configFile;
  ConfigLayer _user = ConfigLayer();

  ConfigLayer get user => _user;

  ConfigLoadResult load() {
    if (_configFile.isEmpty) {
      _user = ConfigLayer();
      return const ConfigStartedFresh();
    }

    final file = File(_configFile);
    if (!file.existsSync()) {
      _user = ConfigLayer();
      return const ConfigStartedFresh();
    }

    final content = file.readAsStringSync().trim();
    if (content.isEmpty) {
      _user = ConfigLayer();
      return const ConfigStartedFresh();
    }

    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Expected a JSON object.');
      }
      _user = ConfigLayer(decoded);
      return const ConfigLoaded();
    } on FormatException {
      final backupPath = _backupCorruptFile(file);
      _user = ConfigLayer();
      return ConfigRecovered(backupPath: backupPath);
    }
  }

  void persist() {
    if (_configFile.isEmpty) return;

    final file = File(_configFile);
    final parent = file.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    File('$_configFile.tmp')
      ..writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_user.toMap()),
        flush: true,
      )
      ..renameSync(_configFile);
  }

  String _backupCorruptFile(File file) {
    final backup = _nextBackupFile(file);
    file.renameSync(backup.path);
    return backup.path;
  }

  File _nextBackupFile(File file) {
    final base = File('${file.path}.bak');
    if (!base.existsSync()) return base;

    var index = 1;
    while (true) {
      final candidate = File('${base.path}.$index');
      if (!candidate.existsSync()) return candidate;
      index += 1;
    }
  }
}
