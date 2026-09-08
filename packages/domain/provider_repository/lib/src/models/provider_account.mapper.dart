// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'provider_account.dart';

class ProviderAccountMapper extends ClassMapperBase<ProviderAccount> {
  ProviderAccountMapper._();

  static ProviderAccountMapper? _instance;
  static ProviderAccountMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProviderAccountMapper._());
      ProviderDescriptorMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ProviderAccount';

  static ProviderDescriptor _$descriptor(ProviderAccount v) => v.descriptor;
  static const Field<ProviderAccount, ProviderDescriptor> _f$descriptor = Field(
    'descriptor',
    _$descriptor,
  );
  static String _$apiKey(ProviderAccount v) => v.apiKey;
  static const Field<ProviderAccount, String> _f$apiKey = Field(
    'apiKey',
    _$apiKey,
  );
  static Uri? _$baseUrl(ProviderAccount v) => v.baseUrl;
  static const Field<ProviderAccount, Uri> _f$baseUrl = Field(
    'baseUrl',
    _$baseUrl,
    opt: true,
  );
  static int? _$fallbackContextWindow(ProviderAccount v) =>
      v.fallbackContextWindow;
  static const Field<ProviderAccount, int> _f$fallbackContextWindow = Field(
    'fallbackContextWindow',
    _$fallbackContextWindow,
    opt: true,
  );

  @override
  final MappableFields<ProviderAccount> fields = const {
    #descriptor: _f$descriptor,
    #apiKey: _f$apiKey,
    #baseUrl: _f$baseUrl,
    #fallbackContextWindow: _f$fallbackContextWindow,
  };

  static ProviderAccount _instantiate(DecodingData data) {
    return ProviderAccount(
      descriptor: data.dec(_f$descriptor),
      apiKey: data.dec(_f$apiKey),
      baseUrl: data.dec(_f$baseUrl),
      fallbackContextWindow: data.dec(_f$fallbackContextWindow),
    );
  }

  @override
  final Function instantiate = _instantiate;
}

mixin ProviderAccountMappable {
  ProviderAccountCopyWith<ProviderAccount, ProviderAccount, ProviderAccount>
  get copyWith =>
      _ProviderAccountCopyWithImpl<ProviderAccount, ProviderAccount>(
        this as ProviderAccount,
        $identity,
        $identity,
      );
  @override
  bool operator ==(Object other) {
    return ProviderAccountMapper.ensureInitialized().equalsValue(
      this as ProviderAccount,
      other,
    );
  }

  @override
  int get hashCode {
    return ProviderAccountMapper.ensureInitialized().hashValue(
      this as ProviderAccount,
    );
  }
}

extension ProviderAccountValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProviderAccount, $Out> {
  ProviderAccountCopyWith<$R, ProviderAccount, $Out> get $asProviderAccount =>
      $base.as((v, t, t2) => _ProviderAccountCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProviderAccountCopyWith<$R, $In extends ProviderAccount, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ProviderDescriptorCopyWith<$R, ProviderDescriptor, ProviderDescriptor>
  get descriptor;
  $R call({
    ProviderDescriptor? descriptor,
    String? apiKey,
    Uri? baseUrl,
    int? fallbackContextWindow,
  });
  ProviderAccountCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ProviderAccountCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProviderAccount, $Out>
    implements ProviderAccountCopyWith<$R, ProviderAccount, $Out> {
  _ProviderAccountCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProviderAccount> $mapper =
      ProviderAccountMapper.ensureInitialized();
  @override
  ProviderDescriptorCopyWith<$R, ProviderDescriptor, ProviderDescriptor>
  get descriptor =>
      $value.descriptor.copyWith.$chain((v) => call(descriptor: v));
  @override
  $R call({
    ProviderDescriptor? descriptor,
    String? apiKey,
    Object? baseUrl = $none,
    Object? fallbackContextWindow = $none,
  }) => $apply(
    FieldCopyWithData({
      if (descriptor != null) #descriptor: descriptor,
      if (apiKey != null) #apiKey: apiKey,
      if (baseUrl != $none) #baseUrl: baseUrl,
      if (fallbackContextWindow != $none)
        #fallbackContextWindow: fallbackContextWindow,
    }),
  );
  @override
  ProviderAccount $make(CopyWithData data) => ProviderAccount(
    descriptor: data.get(#descriptor, or: $value.descriptor),
    apiKey: data.get(#apiKey, or: $value.apiKey),
    baseUrl: data.get(#baseUrl, or: $value.baseUrl),
    fallbackContextWindow: data.get(
      #fallbackContextWindow,
      or: $value.fallbackContextWindow,
    ),
  );

  @override
  ProviderAccountCopyWith<$R2, ProviderAccount, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProviderAccountCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

