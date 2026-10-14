import 'dart:convert';
import 'dart:io';

import 'package:local_server/local_server.dart';
import 'package:local_server_protocol/local_server_protocol.dart';

/// Holds the lock at the first argument from another process until stdin
/// closes, recording itself in it unless told `--silent`.
Future<void> main(List<String> arguments) async {
  final acquired = ServerLock.acquire(arguments.first);
  if (acquired is! ServerLockAcquired) {
    stdout.writeln('refused');
    return;
  }
  if (!arguments.contains('--silent')) {
    acquired.lock.publish(
      ServerLockFile(pid: pid, port: 4321, protocolVersion: 1),
    );
  }
  stdout.writeln('held $pid');
  await stdin.transform(utf8.decoder).drain<void>();
  acquired.lock.release();
}
