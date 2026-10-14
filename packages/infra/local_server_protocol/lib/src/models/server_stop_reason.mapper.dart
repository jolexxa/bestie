// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'server_stop_reason.dart';

class ServerStopReasonMapper extends EnumMapper<ServerStopReason> {
  ServerStopReasonMapper._();

  static ServerStopReasonMapper? _instance;
  static ServerStopReasonMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ServerStopReasonMapper._());
    }
    return _instance!;
  }

  static ServerStopReason fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ServerStopReason decode(dynamic value) {
    switch (value) {
      case r'drained':
        return ServerStopReason.drained;
      case r'unclaimed':
        return ServerStopReason.unclaimed;
      case r'requested':
        return ServerStopReason.requested;
      case r'engine_lost':
        return ServerStopReason.engineLost;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ServerStopReason self) {
    switch (self) {
      case ServerStopReason.drained:
        return r'drained';
      case ServerStopReason.unclaimed:
        return r'unclaimed';
      case ServerStopReason.requested:
        return r'requested';
      case ServerStopReason.engineLost:
        return r'engine_lost';
    }
  }
}

extension ServerStopReasonMapperExtension on ServerStopReason {
  String toValue() {
    ServerStopReasonMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ServerStopReason>(this) as String;
  }
}

