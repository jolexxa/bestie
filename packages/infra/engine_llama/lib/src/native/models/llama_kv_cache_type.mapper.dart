// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'llama_kv_cache_type.dart';

class LlamaKvCacheTypeMapper extends EnumMapper<LlamaKvCacheType> {
  LlamaKvCacheTypeMapper._();

  static LlamaKvCacheTypeMapper? _instance;
  static LlamaKvCacheTypeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlamaKvCacheTypeMapper._());
    }
    return _instance!;
  }

  static LlamaKvCacheType fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  LlamaKvCacheType decode(dynamic value) {
    switch (value) {
      case r'f16':
        return LlamaKvCacheType.f16;
      case r'q8_0':
        return LlamaKvCacheType.q8_0;
      case r'q4_0':
        return LlamaKvCacheType.q4_0;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(LlamaKvCacheType self) {
    switch (self) {
      case LlamaKvCacheType.f16:
        return r'f16';
      case LlamaKvCacheType.q8_0:
        return r'q8_0';
      case LlamaKvCacheType.q4_0:
        return r'q4_0';
    }
  }
}

extension LlamaKvCacheTypeMapperExtension on LlamaKvCacheType {
  String toValue() {
    LlamaKvCacheTypeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<LlamaKvCacheType>(this) as String;
  }
}

