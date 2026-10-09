import 'dart:io';

import 'package:inference_server/inference_server.dart';
import 'package:intentions/intentions.dart';

/// Writes timestamped log lines to a sink, such as stderr or a log file.
@dataSource
final class SinkServerLog implements ServerLog {
  SinkServerLog(this._sink, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final IOSink _sink;
  final DateTime Function() _now;

  @override
  void info(String message) => _write('INFO', message);

  @override
  void error(String message) => _write('ERROR', message);

  void _write(String level, String message) =>
      _sink.writeln('${_now().toIso8601String()} $level $message');
}
