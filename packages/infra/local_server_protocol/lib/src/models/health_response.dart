import 'package:dart_mappable/dart_mappable.dart';

part 'health_response.mapper.dart';

/// The server's answer to the handshake.
@MappableClass(caseStyle: CaseStyle.snakeCase)
final class HealthResponse with HealthResponseMappable {
  const HealthResponse({
    required this.protocolVersion,
    required this.serverVersion,
    required this.pid,
  });

  final int protocolVersion;

  final String serverVersion;

  final int pid;
}
