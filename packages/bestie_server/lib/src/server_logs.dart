import 'package:intentions/intentions.dart';
import 'package:local_server/local_server.dart';

/// Writes timestamped log lines through a line writer, one call per line,
/// so a writer that goes straight to the file loses nothing when the
/// process dies without warning.
@dataSource
final class LineServerLog implements ServerLog {
  LineServerLog(this._writeLine, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final void Function(String line) _writeLine;
  final DateTime Function() _now;

  @override
  void info(String message) => _write('INFO', message);

  @override
  void error(String message) => _write('ERROR', message);

  void _write(String level, String message) =>
      _writeLine('${_now().toIso8601String()} $level $message');
}
