// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'provider_settings.dart';

class ProviderSettingsMapper extends ClassMapperBase<ProviderSettings> {
  ProviderSettingsMapper._();

  static ProviderSettingsMapper? _instance;
  static ProviderSettingsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderSettingsMapper._());
      ProviderAccountMapper.ensureInitialized();
      ProviderModelRefMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderSettings';

  static List<ProviderAccount> _$accounts(ProviderSettings v) => v.accounts;
  static const Field<ProviderSettings, List<ProviderAccount>> _f$accounts =
      Field('accounts', _$accounts);
  static ProviderModelRef? _$model(ProviderSettings v) => v.model;
  static const Field<ProviderSettings, ProviderModelRef> _f$model = Field(
    'model',
    _$model,
  );
  static int _$maxAgents(ProviderSettings v) => v.maxAgents;
  static const Field<ProviderSettings, int> _f$maxAgents = Field(
    'maxAgents',
    _$maxAgents,
  );

  @override
  final MappableFields<ProviderSettings> fields = const {
    #accounts: _f$accounts,
    #model: _f$model,
    #maxAgents: _f$maxAgents,
  };

  static ProviderSettings _instantiate(DecodingData data) {
    return ProviderSettings(
      accounts: data.dec(_f$accounts),
      model: data.dec(_f$model),
      maxAgents: data.dec(_f$maxAgents),
    );
  }

  @override
  final Function instantiate = _instantiate;
}

mixin ProviderSettingsMappable {
  ProviderSettingsCopyWith<ProviderSettings, ProviderSettings, ProviderSettings>
  get copyWith =>
      _ProviderSettingsCopyWithImpl<ProviderSettings, ProviderSettings>(
        this as ProviderSettings,
        $identity,
        $identity,
      );
  @override
  bool operator ==(Object other) {
    return ProviderSettingsMapper.ensureInitialized().equalsValue(
      this as ProviderSettings,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderSettingsMapper.ensureInitialized().hashValue(
      this as ProviderSettings,
    );
  }
}

extension ProviderSettingsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderSettings, $Out> {
  ProviderSettingsCopyWith<$R, ProviderSettings, $Out>
  get $asProviderSettings =>
      $base.as((v, t, t2) => _ProviderSettingsCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProviderSettingsCopyWith<$R, $In extends ProviderSettings, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    ProviderAccount,
    ProviderAccountCopyWith<$R, ProviderAccount, ProviderAccount>
  >
  get accounts;
  ProviderModelRefCopyWith<$R, ProviderModelRef, ProviderModelRef>? get model;
  $R call({
    List<ProviderAccount>? accounts,
    ProviderModelRef? model,
    int? maxAgents,
  });
  ProviderSettingsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderSettingsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderSettings, $Out>
    implements ProviderSettingsCopyWith<$R, ProviderSettings, $Out> {
  _ProviderSettingsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderSettings> $mapper =
      ProviderSettingsMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    ProviderAccount,
    ProviderAccountCopyWith<$R, ProviderAccount, ProviderAccount>
  >
  get accounts => ListCopyWith(
    $value.accounts,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(accounts: v),
  );
  @override
  ProviderModelRefCopyWith<$R, ProviderModelRef, ProviderModelRef>? get model =>
      $value.model?.copyWith.$chain((v) => call(model: v));
  @override
  $R call({
    List<ProviderAccount>? accounts,
    Object? model = $none,
    int? maxAgents,
  }) => $apply(
    FieldCopyWithData({
      if (accounts != null) #accounts: accounts,
      if (model != $none) #model: model,
      if (maxAgents != null) #maxAgents: maxAgents,
    }),
  );
  @override
  ProviderSettings $make(CopyWithData data) => ProviderSettings(
    accounts: data.get(#accounts, or: $value.accounts),
    model: data.get(#model, or: $value.model),
    maxAgents: data.get(#maxAgents, or: $value.maxAgents),
  );

  @override
  ProviderSettingsCopyWith<$R2, ProviderSettings, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProviderSettingsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

