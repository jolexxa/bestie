import 'dart:convert';
import 'dart:io';

import 'package:inference_server/inference_server.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// Holds the lock at the first argument from another process until stdin
/// closes, recording itself in it unless told `--silent`.
Future<void> main(List<String> arguments) async {
  final acquired = InferenceLock.acquire(arguments.first);
  if (acquired is! InferenceLockAcquired) {
    stdout.writeln('refused');
    return;
  }
  if (!arguments.contains('--silent')) {
    acquired.lock.publish(
      InferenceLockFile(pid: pid, port: 4321, protocolVersion: 1),
    );
  }
  stdout.writeln('held');
  await stdin.transform(utf8.decoder).drain<void>();
  acquired.lock.release();
}
