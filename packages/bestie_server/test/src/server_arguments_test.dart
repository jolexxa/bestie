import 'dart:io';

import 'package:bestie_server/bestie_server.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

ServerArguments _parsed(List<String> arguments) =>
    (ServerArguments.parse(arguments, home: '/home/joanna')
            as ServerArgumentsParsed)
        .arguments;

void main() {
  test('defaults to ~/.bestie and stderr', () {
    final arguments = _parsed(const []);

    expect(arguments.bestieDir, p.join('/home/joanna', '.bestie'));
    expect(arguments.logPath, isNull);
  });

  test('reads every flag', () {
    final arguments = _parsed(const [
      '--bestie-dir',
      '/tmp/bestie',
      '--log',
      '/tmp/server.log',
    ]);

    expect(arguments.bestieDir, '/tmp/bestie');
    expect(arguments.logPath, '/tmp/server.log');
  });

  test('asks for help', () {
    expect(
      ServerArguments.parse(const ['--help'], home: '/'),
      isA<ServerArgumentsHelp>(),
    );
    expect(ServerArguments.usage, contains('--bestie-dir'));
  });

  test('refuses unknown flags', () {
    expect(
      ServerArguments.parse(const ['--port', '1'], home: '/'),
      isA<ServerArgumentsInvalid>(),
    );
  });

  test('logs timestamped lines', () async {
    final file = File(
      '${Directory.systemTemp.createTempSync('server_log_').path}/log',
    );
    addTearDown(() => file.parent.deleteSync(recursive: true));
    final sink = file.openWrite();

    SinkServerLog(sink, now: () => DateTime.utc(2026, 10, 4))
      ..info('started')
      ..error('broke');
    await sink.close();

    expect(file.readAsLinesSync(), [
      '2026-10-04T00:00:00.000Z INFO started',
      '2026-10-04T00:00:00.000Z ERROR broke',
    ]);
  });
}
