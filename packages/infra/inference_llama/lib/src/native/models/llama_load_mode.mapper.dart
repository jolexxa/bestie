// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'llama_load_mode.dart';

class LlamaLoadModeMapper extends EnumMapper<LlamaLoadMode> {
  LlamaLoadModeMapper._();

  static LlamaLoadModeMapper? _instance;
  static LlamaLoadModeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LlamaLoadModeMapper._());
    }
    return _instance!;
  }

  static LlamaLoadMode fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  LlamaLoadMode decode(dynamic value) {
    switch (value) {
      case r'auto':
        return LlamaLoadMode.auto;
      case r'none':
        return LlamaLoadMode.none;
      case r'mmap':
        return LlamaLoadMode.mmap;
      case r'mlock':
        return LlamaLoadMode.mlock;
      case r'mmapMlock':
        return LlamaLoadMode.mmapMlock;
      case r'directIo':
        return LlamaLoadMode.directIo;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(LlamaLoadMode self) {
    switch (self) {
      case LlamaLoadMode.auto:
        return r'auto';
      case LlamaLoadMode.none:
        return r'none';
      case LlamaLoadMode.mmap:
        return r'mmap';
      case LlamaLoadMode.mlock:
        return r'mlock';
      case LlamaLoadMode.mmapMlock:
        return r'mmapMlock';
      case LlamaLoadMode.directIo:
        return r'directIo';
    }
  }
}

extension LlamaLoadModeMapperExtension on LlamaLoadMode {
  String toValue() {
    LlamaLoadModeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<LlamaLoadMode>(this) as String;
  }
}

