import 'package:dart_mappable/dart_mappable.dart';

part 'inference_lock_file.mapper.dart';

/// What the running server writes into the file it holds locked, so a client
/// can find it.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class InferenceLockFile with InferenceLockFileMappable {
  const InferenceLockFile({
    required this.pid,
    required this.port,
    required this.protocolVersion,
  });

  static const fileName = 'inference.lock';

  final int pid;

  final int port;

  final int protocolVersion;
}
