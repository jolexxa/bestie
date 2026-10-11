// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'model_profile_id.dart';

class ModelProfileIdMapper extends EnumMapper<ModelProfileId> {
  ModelProfileIdMapper._();

  static ModelProfileIdMapper? _instance;
  static ModelProfileIdMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelProfileIdMapper._());
    }
    return _instance!;
  }

  static ModelProfileId fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ModelProfileId decode(dynamic value) {
    switch (value) {
      case 'qwen3':
        return ModelProfileId.qwen3;
      case 'qwen35':
        return ModelProfileId.qwen35;
      case 'qwen25':
        return ModelProfileId.qwen25;
      case 'gpt_oss':
        return ModelProfileId.gptOss;
      case 'qwen3_coder':
        return ModelProfileId.qwen3Coder;
      case 'gemma4':
        return ModelProfileId.gemma4;
      case 'glm4':
        return ModelProfileId.glm4;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ModelProfileId self) {
    switch (self) {
      case ModelProfileId.qwen3:
        return 'qwen3';
      case ModelProfileId.qwen35:
        return 'qwen35';
      case ModelProfileId.qwen25:
        return 'qwen25';
      case ModelProfileId.gptOss:
        return 'gpt_oss';
      case ModelProfileId.qwen3Coder:
        return 'qwen3_coder';
      case ModelProfileId.gemma4:
        return 'gemma4';
      case ModelProfileId.glm4:
        return 'glm4';
    }
  }
}

extension ModelProfileIdMapperExtension on ModelProfileId {
  dynamic toValue() {
    ModelProfileIdMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ModelProfileId>(this);
  }
}

