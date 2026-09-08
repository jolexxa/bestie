// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'role.dart';

class RoleMapper extends EnumMapper<Role> {
  RoleMapper._();

  static RoleMapper? _instance;
  static RoleMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RoleMapper._());
    }
    return _instance!;
  }

  static Role fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  Role decode(dynamic value) {
    switch (value) {
      case 'system':
        return Role.system;
      case 'user':
        return Role.user;
      case 'assistant':
        return Role.assistant;
      case 'tool':
        return Role.tool;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(Role self) {
    switch (self) {
      case Role.system:
        return 'system';
      case Role.user:
        return 'user';
      case Role.assistant:
        return 'assistant';
      case Role.tool:
        return 'tool';
    }
  }
}

extension RoleMapperExtension on Role {
  dynamic toValue() {
    RoleMapper.ensureInitialized();
    return MapperContainer.globals.toValue<Role>(this);
  }
}

