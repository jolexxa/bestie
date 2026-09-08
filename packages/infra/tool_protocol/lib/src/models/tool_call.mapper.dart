// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'tool_call.dart';

class ToolCallMapper extends ClassMapperBase<ToolCall> {
  ToolCallMapper._();

  static ToolCallMapper? _instance;
  static ToolCallMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallMapper._());
      ToolCallDefaultMapper.ensureInitialized();
      ToolCallReasoningMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCall';

  static String _$id(ToolCall v) => v.id;
  static const Field<ToolCall, String> _f$id = Field('id', _$id);
  static String _$name(ToolCall v) => v.name;
  static const Field<ToolCall, String> _f$name = Field('name', _$name);
  static Map<String, Object?> _$arguments(ToolCall v) => v.arguments;
  static const Field<ToolCall, Map<String, Object?>> _f$arguments = Field(
    'arguments',
    _$arguments,
  );

  @override
  final MappableFields<ToolCall> fields = const {
    #id: _f$id,
    #name: _f$name,
    #arguments: _f$arguments,
  };

  static ToolCall _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ToolCall',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCall fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCall>(map);
  }

  static ToolCall fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCall>(json);
  }
}

mixin ToolCallMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ToolCallCopyWith<ToolCall, ToolCall, ToolCall> get copyWith;
}

abstract class ToolCallCopyWith<$R, $In extends ToolCall, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get arguments;
  $R call({String? id, String? name, Map<String, Object?>? arguments});
  ToolCallCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class ToolCallDefaultMapper extends SubClassMapperBase<ToolCallDefault> {
  ToolCallDefaultMapper._();

  static ToolCallDefaultMapper? _instance;
  static ToolCallDefaultMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallDefaultMapper._());
      ToolCallMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCallDefault';

  static String _$id(ToolCallDefault v) => v.id;
  static const Field<ToolCallDefault, String> _f$id = Field('id', _$id);
  static String _$name(ToolCallDefault v) => v.name;
  static const Field<ToolCallDefault, String> _f$name = Field('name', _$name);
  static Map<String, Object?> _$arguments(ToolCallDefault v) => v.arguments;
  static const Field<ToolCallDefault, Map<String, Object?>> _f$arguments =
      Field('arguments', _$arguments);

  @override
  final MappableFields<ToolCallDefault> fields = const {
    #id: _f$id,
    #name: _f$name,
    #arguments: _f$arguments,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'default';
  @override
  late final ClassMapperBase superMapper = ToolCallMapper.ensureInitialized();

  static ToolCallDefault _instantiate(DecodingData data) {
    return ToolCallDefault(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      arguments: data.dec(_f$arguments),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCallDefault fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCallDefault>(map);
  }

  static ToolCallDefault fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCallDefault>(json);
  }
}

mixin ToolCallDefaultMappable {
  String toJson() {
    return ToolCallDefaultMapper.ensureInitialized()
        .encodeJson<ToolCallDefault>(this as ToolCallDefault);
  }

  Map<String, dynamic> toMap() {
    return ToolCallDefaultMapper.ensureInitialized().encodeMap<ToolCallDefault>(
      this as ToolCallDefault,
    );
  }

  ToolCallDefaultCopyWith<ToolCallDefault, ToolCallDefault, ToolCallDefault>
  get copyWith =>
      _ToolCallDefaultCopyWithImpl<ToolCallDefault, ToolCallDefault>(
        this as ToolCallDefault,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ToolCallDefaultMapper.ensureInitialized().stringifyValue(
      this as ToolCallDefault,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolCallDefaultMapper.ensureInitialized().equalsValue(
      this as ToolCallDefault,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolCallDefaultMapper.ensureInitialized().hashValue(
      this as ToolCallDefault,
    );
  }
}

extension ToolCallDefaultValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolCallDefault, $Out> {
  ToolCallDefaultCopyWith<$R, ToolCallDefault, $Out> get $asToolCallDefault =>
      $base.as((v, t, t2) => _ToolCallDefaultCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ToolCallDefaultCopyWith<$R, $In extends ToolCallDefault, $Out>
    implements ToolCallCopyWith<$R, $In, $Out> {
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get arguments;
  @override
  $R call({String? id, String? name, Map<String, Object?>? arguments});
  ToolCallDefaultCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolCallDefaultCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolCallDefault, $Out>
    implements ToolCallDefaultCopyWith<$R, ToolCallDefault, $Out> {
  _ToolCallDefaultCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolCallDefault> $mapper =
      ToolCallDefaultMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get arguments => MapCopyWith(
    $value.arguments,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(arguments: v),
  );
  @override
  $R call({String? id, String? name, Map<String, Object?>? arguments}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (name != null) #name: name,
          if (arguments != null) #arguments: arguments,
        }),
      );
  @override
  ToolCallDefault $make(CopyWithData data) => ToolCallDefault(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    arguments: data.get(#arguments, or: $value.arguments),
  );

  @override
  ToolCallDefaultCopyWith<$R2, ToolCallDefault, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolCallDefaultCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ToolCallReasoningMapper extends SubClassMapperBase<ToolCallReasoning> {
  ToolCallReasoningMapper._();

  static ToolCallReasoningMapper? _instance;
  static ToolCallReasoningMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallReasoningMapper._());
      ToolCallMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCallReasoning';

  static String _$id(ToolCallReasoning v) => v.id;
  static const Field<ToolCallReasoning, String> _f$id = Field('id', _$id);
  static String _$name(ToolCallReasoning v) => v.name;
  static const Field<ToolCallReasoning, String> _f$name = Field('name', _$name);
  static Map<String, Object?> _$arguments(ToolCallReasoning v) => v.arguments;
  static const Field<ToolCallReasoning, Map<String, Object?>> _f$arguments =
      Field('arguments', _$arguments);

  @override
  final MappableFields<ToolCallReasoning> fields = const {
    #id: _f$id,
    #name: _f$name,
    #arguments: _f$arguments,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'reasoning';
  @override
  late final ClassMapperBase superMapper = ToolCallMapper.ensureInitialized();

  static ToolCallReasoning _instantiate(DecodingData data) {
    return ToolCallReasoning(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      arguments: data.dec(_f$arguments),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCallReasoning fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCallReasoning>(map);
  }

  static ToolCallReasoning fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCallReasoning>(json);
  }
}

mixin ToolCallReasoningMappable {
  String toJson() {
    return ToolCallReasoningMapper.ensureInitialized()
        .encodeJson<ToolCallReasoning>(this as ToolCallReasoning);
  }

  Map<String, dynamic> toMap() {
    return ToolCallReasoningMapper.ensureInitialized()
        .encodeMap<ToolCallReasoning>(this as ToolCallReasoning);
  }

  ToolCallReasoningCopyWith<
    ToolCallReasoning,
    ToolCallReasoning,
    ToolCallReasoning
  >
  get copyWith =>
      _ToolCallReasoningCopyWithImpl<ToolCallReasoning, ToolCallReasoning>(
        this as ToolCallReasoning,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ToolCallReasoningMapper.ensureInitialized().stringifyValue(
      this as ToolCallReasoning,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolCallReasoningMapper.ensureInitialized().equalsValue(
      this as ToolCallReasoning,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolCallReasoningMapper.ensureInitialized().hashValue(
      this as ToolCallReasoning,
    );
  }
}

extension ToolCallReasoningValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolCallReasoning, $Out> {
  ToolCallReasoningCopyWith<$R, ToolCallReasoning, $Out>
  get $asToolCallReasoning => $base.as(
    (v, t, t2) => _ToolCallReasoningCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ToolCallReasoningCopyWith<
  $R,
  $In extends ToolCallReasoning,
  $Out
>
    implements ToolCallCopyWith<$R, $In, $Out> {
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get arguments;
  @override
  $R call({String? id, String? name, Map<String, Object?>? arguments});
  ToolCallReasoningCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolCallReasoningCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolCallReasoning, $Out>
    implements ToolCallReasoningCopyWith<$R, ToolCallReasoning, $Out> {
  _ToolCallReasoningCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolCallReasoning> $mapper =
      ToolCallReasoningMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get arguments => MapCopyWith(
    $value.arguments,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(arguments: v),
  );
  @override
  $R call({String? id, String? name, Map<String, Object?>? arguments}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (name != null) #name: name,
          if (arguments != null) #arguments: arguments,
        }),
      );
  @override
  ToolCallReasoning $make(CopyWithData data) => ToolCallReasoning(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    arguments: data.get(#arguments, or: $value.arguments),
  );

  @override
  ToolCallReasoningCopyWith<$R2, ToolCallReasoning, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolCallReasoningCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

