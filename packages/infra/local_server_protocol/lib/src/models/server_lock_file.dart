import 'package:dart_mappable/dart_mappable.dart';

part 'server_lock_file.mapper.dart';

/// What the running server writes into the file it holds locked, so a client
/// can find it.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class ServerLockFile with ServerLockFileMappable {
  const ServerLockFile({
    required this.pid,
    required this.port,
    required this.protocolVersion,
  });

  static const fileName = 'server.lock';

  final int pid;

  final int port;

  final int protocolVersion;
}
