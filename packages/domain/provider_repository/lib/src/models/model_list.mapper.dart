// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'model_list.dart';

class ListedModelMapper extends ClassMapperBase<ListedModel> {
  ListedModelMapper._();

  static ListedModelMapper? _instance;
  static ListedModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ListedModelMapper._());
      ProviderModelRefMapper.ensureInitialized();
      ProviderModelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ListedModel';

  static ProviderModelRef _$ref(ListedModel v) => v.ref;
  static const Field<ListedModel, ProviderModelRef> _f$ref = Field(
    'ref',
    _$ref,
  );
  static ProviderModel _$model(ListedModel v) => v.model;
  static const Field<ListedModel, ProviderModel> _f$model = Field(
    'model',
    _$model,
  );
  static String _$providerName(ListedModel v) => v.providerName;
  static const Field<ListedModel, String> _f$providerName = Field(
    'providerName',
    _$providerName,
  );
  static bool _$hasAccess(ListedModel v) => v.hasAccess;
  static const Field<ListedModel, bool> _f$hasAccess = Field(
    'hasAccess',
    _$hasAccess,
  );

  @override
  final MappableFields<ListedModel> fields = const {
    #ref: _f$ref,
    #model: _f$model,
    #providerName: _f$providerName,
    #hasAccess: _f$hasAccess,
  };

  static ListedModel _instantiate(DecodingData data) {
    return ListedModel(
      ref: data.dec(_f$ref),
      model: data.dec(_f$model),
      providerName: data.dec(_f$providerName),
      hasAccess: data.dec(_f$hasAccess),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ListedModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ListedModel>(map);
  }

  static ListedModel fromJson(String json) {
    return ensureInitialized().decodeJson<ListedModel>(json);
  }
}

mixin ListedModelMappable {
  String toJson() {
    return ListedModelMapper.ensureInitialized().encodeJson<ListedModel>(
      this as ListedModel,
    );
  }

  Map<String, dynamic> toMap() {
    return ListedModelMapper.ensureInitialized().encodeMap<ListedModel>(
      this as ListedModel,
    );
  }

  ListedModelCopyWith<ListedModel, ListedModel, ListedModel> get copyWith =>
      _ListedModelCopyWithImpl<ListedModel, ListedModel>(
        this as ListedModel,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ListedModelMapper.ensureInitialized().stringifyValue(
      this as ListedModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return ListedModelMapper.ensureInitialized().equalsValue(
      this as ListedModel,
      other,
    );
  }

  @override
  int get hashCode {
    return ListedModelMapper.ensureInitialized().hashValue(this as ListedModel);
  }
}

extension ListedModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ListedModel, $Out> {
  ListedModelCopyWith<$R, ListedModel, $Out> get $asListedModel =>
      $base.as((v, t, t2) => _ListedModelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ListedModelCopyWith<$R, $In extends ListedModel, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ProviderModelRefCopyWith<$R, ProviderModelRef, ProviderModelRef> get ref;
  ProviderModelCopyWith<$R, ProviderModel, ProviderModel> get model;
  $R call({
    ProviderModelRef? ref,
    ProviderModel? model,
    String? providerName,
    bool? hasAccess,
  });
  ListedModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ListedModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ListedModel, $Out>
    implements ListedModelCopyWith<$R, ListedModel, $Out> {
  _ListedModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ListedModel> $mapper =
      ListedModelMapper.ensureInitialized();
  @override
  ProviderModelRefCopyWith<$R, ProviderModelRef, ProviderModelRef> get ref =>
      $value.ref.copyWith.$chain((v) => call(ref: v));
  @override
  ProviderModelCopyWith<$R, ProviderModel, ProviderModel> get model =>
      $value.model.copyWith.$chain((v) => call(model: v));
  @override
  $R call({
    ProviderModelRef? ref,
    ProviderModel? model,
    String? providerName,
    bool? hasAccess,
  }) => $apply(
    FieldCopyWithData({
      if (ref != null) #ref: ref,
      if (model != null) #model: model,
      if (providerName != null) #providerName: providerName,
      if (hasAccess != null) #hasAccess: hasAccess,
    }),
  );
  @override
  ListedModel $make(CopyWithData data) => ListedModel(
    ref: data.get(#ref, or: $value.ref),
    model: data.get(#model, or: $value.model),
    providerName: data.get(#providerName, or: $value.providerName),
    hasAccess: data.get(#hasAccess, or: $value.hasAccess),
  );

  @override
  ListedModelCopyWith<$R2, ListedModel, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ListedModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

