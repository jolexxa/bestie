import 'package:dart_mappable/dart_mappable.dart';

part 'server_stop_reason.mapper.dart';

/// Why a server stopped.
@MappableEnum(caseStyle: CaseStyle.snakeCase)
enum ServerStopReason {
  /// Its last connection closed.
  drained,

  /// Nothing connected within the startup grace.
  unclaimed,

  /// The process was asked to stop.
  requested,

  /// The engine it loads models with is gone.
  engineLost,
}
