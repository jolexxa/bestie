// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'effective_policy.dart';

class EffectivePolicyMapper extends ClassMapperBase<EffectivePolicy> {
  EffectivePolicyMapper._();

  static EffectivePolicyMapper? _instance;
  static EffectivePolicyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = EffectivePolicyMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'EffectivePolicy';

  static List<String> _$readableRoots(EffectivePolicy v) => v.readableRoots;
  static const Field<EffectivePolicy, List<String>> _f$readableRoots = Field(
    'readableRoots',
    _$readableRoots,
    opt: true,
    def: const [],
  );
  static List<String> _$writableRoots(EffectivePolicy v) => v.writableRoots;
  static const Field<EffectivePolicy, List<String>> _f$writableRoots = Field(
    'writableRoots',
    _$writableRoots,
    opt: true,
    def: const [],
  );
  static List<String> _$deniedReads(EffectivePolicy v) => v.deniedReads;
  static const Field<EffectivePolicy, List<String>> _f$deniedReads = Field(
    'deniedReads',
    _$deniedReads,
    opt: true,
    def: const [],
  );

  @override
  final MappableFields<EffectivePolicy> fields = const {
    #readableRoots: _f$readableRoots,
    #writableRoots: _f$writableRoots,
    #deniedReads: _f$deniedReads,
  };

  static EffectivePolicy _instantiate(DecodingData data) {
    return EffectivePolicy(
      readableRoots: data.dec(_f$readableRoots),
      writableRoots: data.dec(_f$writableRoots),
      deniedReads: data.dec(_f$deniedReads),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static EffectivePolicy fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<EffectivePolicy>(map);
  }

  static EffectivePolicy fromJson(String json) {
    return ensureInitialized().decodeJson<EffectivePolicy>(json);
  }
}

mixin EffectivePolicyMappable {
  String toJson() {
    return EffectivePolicyMapper.ensureInitialized()
        .encodeJson<EffectivePolicy>(this as EffectivePolicy);
  }

  Map<String, dynamic> toMap() {
    return EffectivePolicyMapper.ensureInitialized().encodeMap<EffectivePolicy>(
      this as EffectivePolicy,
    );
  }

  EffectivePolicyCopyWith<EffectivePolicy, EffectivePolicy, EffectivePolicy>
  get copyWith =>
      _EffectivePolicyCopyWithImpl<EffectivePolicy, EffectivePolicy>(
        this as EffectivePolicy,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return EffectivePolicyMapper.ensureInitialized().stringifyValue(
      this as EffectivePolicy,
    );
  }

  @override
  bool operator ==(Object other) {
    return EffectivePolicyMapper.ensureInitialized().equalsValue(
      this as EffectivePolicy,
      other,
    );
  }

  @override
  int get hashCode {
    return EffectivePolicyMapper.ensureInitialized().hashValue(
      this as EffectivePolicy,
    );
  }
}

extension EffectivePolicyValueCopy<$R, $Out>
    on ObjectCopyWith<$R, EffectivePolicy, $Out> {
  EffectivePolicyCopyWith<$R, EffectivePolicy, $Out> get $asEffectivePolicy =>
      $base.as((v, t, t2) => _EffectivePolicyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class EffectivePolicyCopyWith<$R, $In extends EffectivePolicy, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get readableRoots;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get writableRoots;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get deniedReads;
  $R call({
    List<String>? readableRoots,
    List<String>? writableRoots,
    List<String>? deniedReads,
  });
  EffectivePolicyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _EffectivePolicyCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, EffectivePolicy, $Out>
    implements EffectivePolicyCopyWith<$R, EffectivePolicy, $Out> {
  _EffectivePolicyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<EffectivePolicy> $mapper =
      EffectivePolicyMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get readableRoots => ListCopyWith(
    $value.readableRoots,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(readableRoots: v),
  );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get writableRoots => ListCopyWith(
    $value.writableRoots,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(writableRoots: v),
  );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get deniedReads => ListCopyWith(
    $value.deniedReads,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(deniedReads: v),
  );
  @override
  $R call({
    List<String>? readableRoots,
    List<String>? writableRoots,
    List<String>? deniedReads,
  }) => $apply(
    FieldCopyWithData({
      if (readableRoots != null) #readableRoots: readableRoots,
      if (writableRoots != null) #writableRoots: writableRoots,
      if (deniedReads != null) #deniedReads: deniedReads,
    }),
  );
  @override
  EffectivePolicy $make(CopyWithData data) => EffectivePolicy(
    readableRoots: data.get(#readableRoots, or: $value.readableRoots),
    writableRoots: data.get(#writableRoots, or: $value.writableRoots),
    deniedReads: data.get(#deniedReads, or: $value.deniedReads),
  );

  @override
  EffectivePolicyCopyWith<$R2, EffectivePolicy, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _EffectivePolicyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

