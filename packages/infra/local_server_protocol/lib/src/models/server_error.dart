import 'package:dart_mappable/dart_mappable.dart';

part 'server_error.mapper.dart';

/// A typed error body the server sends instead of a plain status.
@MappableClass(caseStyle: CaseStyle.snakeCase, discriminatorKey: 'error')
sealed class ServerError with ServerErrorMappable {
  const ServerError();
}

/// Another bestie already holds the owner session; sent with a 409.
@MappableClass(
  caseStyle: CaseStyle.snakeCase,
  discriminatorValue: 'server_busy',
)
final class ServerBusy extends ServerError with ServerBusyMappable {
  const ServerBusy({required this.ownerPid});

  static const statusCode = 409;

  final int ownerPid;
}
