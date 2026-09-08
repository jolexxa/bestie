// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'job_in_background.dart';

class JobInBackgroundMapper extends ClassMapperBase<JobInBackground> {
  JobInBackgroundMapper._();

  static JobInBackgroundMapper? _instance;
  static JobInBackgroundMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JobInBackgroundMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'JobInBackground';

  static String _$callId(JobInBackground v) => v.callId;
  static const Field<JobInBackground, String> _f$callId = Field(
    'callId',
    _$callId,
  );
  static String _$toolName(JobInBackground v) => v.toolName;
  static const Field<JobInBackground, String> _f$toolName = Field(
    'toolName',
    _$toolName,
  );
  static String _$labelTemplate(JobInBackground v) => v.labelTemplate;
  static const Field<JobInBackground, String> _f$labelTemplate = Field(
    'labelTemplate',
    _$labelTemplate,
    opt: true,
    def: '',
  );
  static Map<String, Object?> _$labelArguments(JobInBackground v) =>
      v.labelArguments;
  static const Field<JobInBackground, Map<String, Object?>> _f$labelArguments =
      Field('labelArguments', _$labelArguments, opt: true, def: const {});

  @override
  final MappableFields<JobInBackground> fields = const {
    #callId: _f$callId,
    #toolName: _f$toolName,
    #labelTemplate: _f$labelTemplate,
    #labelArguments: _f$labelArguments,
  };

  static JobInBackground _instantiate(DecodingData data) {
    return JobInBackground(
      callId: data.dec(_f$callId),
      toolName: data.dec(_f$toolName),
      labelTemplate: data.dec(_f$labelTemplate),
      labelArguments: data.dec(_f$labelArguments),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JobInBackground fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JobInBackground>(map);
  }

  static JobInBackground fromJson(String json) {
    return ensureInitialized().decodeJson<JobInBackground>(json);
  }
}

mixin JobInBackgroundMappable {
  String toJson() {
    return JobInBackgroundMapper.ensureInitialized()
        .encodeJson<JobInBackground>(this as JobInBackground);
  }

  Map<String, dynamic> toMap() {
    return JobInBackgroundMapper.ensureInitialized().encodeMap<JobInBackground>(
      this as JobInBackground,
    );
  }

  JobInBackgroundCopyWith<JobInBackground, JobInBackground, JobInBackground>
  get copyWith =>
      _JobInBackgroundCopyWithImpl<JobInBackground, JobInBackground>(
        this as JobInBackground,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return JobInBackgroundMapper.ensureInitialized().stringifyValue(
      this as JobInBackground,
    );
  }

  @override
  bool operator ==(Object other) {
    return JobInBackgroundMapper.ensureInitialized().equalsValue(
      this as JobInBackground,
      other,
    );
  }

  @override
  int get hashCode {
    return JobInBackgroundMapper.ensureInitialized().hashValue(
      this as JobInBackground,
    );
  }
}

extension JobInBackgroundValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JobInBackground, $Out> {
  JobInBackgroundCopyWith<$R, JobInBackground, $Out> get $asJobInBackground =>
      $base.as((v, t, t2) => _JobInBackgroundCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class JobInBackgroundCopyWith<$R, $In extends JobInBackground, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get labelArguments;
  $R call({
    String? callId,
    String? toolName,
    String? labelTemplate,
    Map<String, Object?>? labelArguments,
  });
  JobInBackgroundCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _JobInBackgroundCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JobInBackground, $Out>
    implements JobInBackgroundCopyWith<$R, JobInBackground, $Out> {
  _JobInBackgroundCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JobInBackground> $mapper =
      JobInBackgroundMapper.ensureInitialized();
  @override
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get labelArguments => MapCopyWith(
    $value.labelArguments,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(labelArguments: v),
  );
  @override
  $R call({
    String? callId,
    String? toolName,
    String? labelTemplate,
    Map<String, Object?>? labelArguments,
  }) => $apply(
    FieldCopyWithData({
      if (callId != null) #callId: callId,
      if (toolName != null) #toolName: toolName,
      if (labelTemplate != null) #labelTemplate: labelTemplate,
      if (labelArguments != null) #labelArguments: labelArguments,
    }),
  );
  @override
  JobInBackground $make(CopyWithData data) => JobInBackground(
    callId: data.get(#callId, or: $value.callId),
    toolName: data.get(#toolName, or: $value.toolName),
    labelTemplate: data.get(#labelTemplate, or: $value.labelTemplate),
    labelArguments: data.get(#labelArguments, or: $value.labelArguments),
  );

  @override
  JobInBackgroundCopyWith<$R2, JobInBackground, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _JobInBackgroundCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

