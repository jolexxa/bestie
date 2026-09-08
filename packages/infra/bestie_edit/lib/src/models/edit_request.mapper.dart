// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'edit_request.dart';

class EditRequestMapper extends ClassMapperBase<EditRequest> {
  EditRequestMapper._();

  static EditRequestMapper? _instance;
  static EditRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EditRequestMapper._());
      ReplaceRequestMapper.ensureInitialized();
      CreateRequestMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'EditRequest';

  @override
  final MappableFields<EditRequest> fields = const {};

  static EditRequest _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'EditRequest',
      'action',
      '${data.value['action']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static EditRequest fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EditRequest>(map);
  }

  static EditRequest fromJson(String json) {
    return ensureInitialized().decodeJson<EditRequest>(json);
  }
}

mixin EditRequestMappable {
  String toJson();
  Map<String, dynamic> toMap();
  EditRequestCopyWith<EditRequest, EditRequest, EditRequest> get copyWith;
}

abstract class EditRequestCopyWith<$R, $In extends EditRequest, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  EditRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class ReplaceRequestMapper extends SubClassMapperBase<ReplaceRequest> {
  ReplaceRequestMapper._();

  static ReplaceRequestMapper? _instance;
  static ReplaceRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ReplaceRequestMapper._());
      EditRequestMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ReplaceRequest';

  static String _$path(ReplaceRequest v) => v.path;
  static const Field<ReplaceRequest, String> _f$path = Field('path', _$path);
  static String _$oldText(ReplaceRequest v) => v.oldText;
  static const Field<ReplaceRequest, String> _f$oldText = Field(
    'oldText',
    _$oldText,
    key: r'old',
  );
  static String _$newText(ReplaceRequest v) => v.newText;
  static const Field<ReplaceRequest, String> _f$newText = Field(
    'newText',
    _$newText,
    key: r'new',
  );
  static bool _$replaceAll(ReplaceRequest v) => v.replaceAll;
  static const Field<ReplaceRequest, bool> _f$replaceAll = Field(
    'replaceAll',
    _$replaceAll,
    opt: true,
    def: false,
  );

  @override
  final MappableFields<ReplaceRequest> fields = const {
    #path: _f$path,
    #oldText: _f$oldText,
    #newText: _f$newText,
    #replaceAll: _f$replaceAll,
  };

  @override
  final String discriminatorKey = 'action';
  @override
  final dynamic discriminatorValue = 'edit';
  @override
  late final ClassMapperBase superMapper =
      EditRequestMapper.ensureInitialized();

  static ReplaceRequest _instantiate(DecodingData data) {
    return ReplaceRequest(
      path: data.dec(_f$path),
      oldText: data.dec(_f$oldText),
      newText: data.dec(_f$newText),
      replaceAll: data.dec(_f$replaceAll),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ReplaceRequest fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ReplaceRequest>(map);
  }

  static ReplaceRequest fromJson(String json) {
    return ensureInitialized().decodeJson<ReplaceRequest>(json);
  }
}

mixin ReplaceRequestMappable {
  String toJson() {
    return ReplaceRequestMapper.ensureInitialized().encodeJson<ReplaceRequest>(
      this as ReplaceRequest,
    );
  }

  Map<String, dynamic> toMap() {
    return ReplaceRequestMapper.ensureInitialized().encodeMap<ReplaceRequest>(
      this as ReplaceRequest,
    );
  }

  ReplaceRequestCopyWith<ReplaceRequest, ReplaceRequest, ReplaceRequest>
  get copyWith => _ReplaceRequestCopyWithImpl<ReplaceRequest, ReplaceRequest>(
    this as ReplaceRequest,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ReplaceRequestMapper.ensureInitialized().stringifyValue(
      this as ReplaceRequest,
    );
  }

  @override
  bool operator ==(Object other) {
    return ReplaceRequestMapper.ensureInitialized().equalsValue(
      this as ReplaceRequest,
      other,
    );
  }

  @override
  int get hashCode {
    return ReplaceRequestMapper.ensureInitialized().hashValue(
      this as ReplaceRequest,
    );
  }
}

extension ReplaceRequestValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ReplaceRequest, $Out> {
  ReplaceRequestCopyWith<$R, ReplaceRequest, $Out> get $asReplaceRequest =>
      $base.as((v, t, t2) => _ReplaceRequestCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ReplaceRequestCopyWith<$R, $In extends ReplaceRequest, $Out>
    implements EditRequestCopyWith<$R, $In, $Out> {
  @override
  $R call({String? path, String? oldText, String? newText, bool? replaceAll});
  ReplaceRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ReplaceRequestCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ReplaceRequest, $Out>
    implements ReplaceRequestCopyWith<$R, ReplaceRequest, $Out> {
  _ReplaceRequestCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ReplaceRequest> $mapper =
      ReplaceRequestMapper.ensureInitialized();
  @override
  $R call({String? path, String? oldText, String? newText, bool? replaceAll}) =>
      $apply(
        FieldCopyWithData({
          if (path != null) #path: path,
          if (oldText != null) #oldText: oldText,
          if (newText != null) #newText: newText,
          if (replaceAll != null) #replaceAll: replaceAll,
        }),
      );
  @override
  ReplaceRequest $make(CopyWithData data) => ReplaceRequest(
    path: data.get(#path, or: $value.path),
    oldText: data.get(#oldText, or: $value.oldText),
    newText: data.get(#newText, or: $value.newText),
    replaceAll: data.get(#replaceAll, or: $value.replaceAll),
  );

  @override
  ReplaceRequestCopyWith<$R2, ReplaceRequest, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ReplaceRequestCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CreateRequestMapper extends SubClassMapperBase<CreateRequest> {
  CreateRequestMapper._();

  static CreateRequestMapper? _instance;
  static CreateRequestMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreateRequestMapper._());
      EditRequestMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'CreateRequest';

  static String _$path(CreateRequest v) => v.path;
  static const Field<CreateRequest, String> _f$path = Field('path', _$path);
  static String _$contents(CreateRequest v) => v.contents;
  static const Field<CreateRequest, String> _f$contents = Field(
    'contents',
    _$contents,
  );

  @override
  final MappableFields<CreateRequest> fields = const {
    #path: _f$path,
    #contents: _f$contents,
  };

  @override
  final String discriminatorKey = 'action';
  @override
  final dynamic discriminatorValue = 'create';
  @override
  late final ClassMapperBase superMapper =
      EditRequestMapper.ensureInitialized();

  static CreateRequest _instantiate(DecodingData data) {
    return CreateRequest(
      path: data.dec(_f$path),
      contents: data.dec(_f$contents),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreateRequest fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreateRequest>(map);
  }

  static CreateRequest fromJson(String json) {
    return ensureInitialized().decodeJson<CreateRequest>(json);
  }
}

mixin CreateRequestMappable {
  String toJson() {
    return CreateRequestMapper.ensureInitialized().encodeJson<CreateRequest>(
      this as CreateRequest,
    );
  }

  Map<String, dynamic> toMap() {
    return CreateRequestMapper.ensureInitialized().encodeMap<CreateRequest>(
      this as CreateRequest,
    );
  }

  CreateRequestCopyWith<CreateRequest, CreateRequest, CreateRequest>
  get copyWith => _CreateRequestCopyWithImpl<CreateRequest, CreateRequest>(
    this as CreateRequest,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return CreateRequestMapper.ensureInitialized().stringifyValue(
      this as CreateRequest,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreateRequestMapper.ensureInitialized().equalsValue(
      this as CreateRequest,
      other,
    );
  }

  @override
  int get hashCode {
    return CreateRequestMapper.ensureInitialized().hashValue(
      this as CreateRequest,
    );
  }
}

extension CreateRequestValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreateRequest, $Out> {
  CreateRequestCopyWith<$R, CreateRequest, $Out> get $asCreateRequest =>
      $base.as((v, t, t2) => _CreateRequestCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CreateRequestCopyWith<$R, $In extends CreateRequest, $Out>
    implements EditRequestCopyWith<$R, $In, $Out> {
  @override
  $R call({String? path, String? contents});
  CreateRequestCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CreateRequestCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreateRequest, $Out>
    implements CreateRequestCopyWith<$R, CreateRequest, $Out> {
  _CreateRequestCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreateRequest> $mapper =
      CreateRequestMapper.ensureInitialized();
  @override
  $R call({String? path, String? contents}) => $apply(
    FieldCopyWithData({
      if (path != null) #path: path,
      if (contents != null) #contents: contents,
    }),
  );
  @override
  CreateRequest $make(CopyWithData data) => CreateRequest(
    path: data.get(#path, or: $value.path),
    contents: data.get(#contents, or: $value.contents),
  );

  @override
  CreateRequestCopyWith<$R2, CreateRequest, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CreateRequestCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

