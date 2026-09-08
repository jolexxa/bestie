// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'job_report.dart';

class DeliveredJobReportMapper extends ClassMapperBase<DeliveredJobReport> {
  DeliveredJobReportMapper._();

  static DeliveredJobReportMapper? _instance;
  static DeliveredJobReportMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeliveredJobReportMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'DeliveredJobReport';

  static String _$callId(DeliveredJobReport v) => v.callId;
  static const Field<DeliveredJobReport, String> _f$callId = Field(
    'callId',
    _$callId,
  );
  static String _$toolName(DeliveredJobReport v) => v.toolName;
  static const Field<DeliveredJobReport, String> _f$toolName = Field(
    'toolName',
    _$toolName,
  );
  static bool _$succeeded(DeliveredJobReport v) => v.succeeded;
  static const Field<DeliveredJobReport, bool> _f$succeeded = Field(
    'succeeded',
    _$succeeded,
  );
  static String _$body(DeliveredJobReport v) => v.body;
  static const Field<DeliveredJobReport, String> _f$body = Field(
    'body',
    _$body,
  );
  static int _$outstanding(DeliveredJobReport v) => v.outstanding;
  static const Field<DeliveredJobReport, int> _f$outstanding = Field(
    'outstanding',
    _$outstanding,
  );
  static String _$labelTemplate(DeliveredJobReport v) => v.labelTemplate;
  static const Field<DeliveredJobReport, String> _f$labelTemplate = Field(
    'labelTemplate',
    _$labelTemplate,
    opt: true,
    def: '',
  );
  static Map<String, Object?> _$labelArguments(DeliveredJobReport v) =>
      v.labelArguments;
  static const Field<DeliveredJobReport, Map<String, Object?>>
  _f$labelArguments = Field(
    'labelArguments',
    _$labelArguments,
    opt: true,
    def: const {},
  );

  @override
  final MappableFields<DeliveredJobReport> fields = const {
    #callId: _f$callId,
    #toolName: _f$toolName,
    #succeeded: _f$succeeded,
    #body: _f$body,
    #outstanding: _f$outstanding,
    #labelTemplate: _f$labelTemplate,
    #labelArguments: _f$labelArguments,
  };

  static DeliveredJobReport _instantiate(DecodingData data) {
    return DeliveredJobReport(
      callId: data.dec(_f$callId),
      toolName: data.dec(_f$toolName),
      succeeded: data.dec(_f$succeeded),
      body: data.dec(_f$body),
      outstanding: data.dec(_f$outstanding),
      labelTemplate: data.dec(_f$labelTemplate),
      labelArguments: data.dec(_f$labelArguments),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DeliveredJobReport fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DeliveredJobReport>(map);
  }

  static DeliveredJobReport fromJson(String json) {
    return ensureInitialized().decodeJson<DeliveredJobReport>(json);
  }
}

mixin DeliveredJobReportMappable {
  String toJson() {
    return DeliveredJobReportMapper.ensureInitialized()
        .encodeJson<DeliveredJobReport>(this as DeliveredJobReport);
  }

  Map<String, dynamic> toMap() {
    return DeliveredJobReportMapper.ensureInitialized()
        .encodeMap<DeliveredJobReport>(this as DeliveredJobReport);
  }

  DeliveredJobReportCopyWith<
    DeliveredJobReport,
    DeliveredJobReport,
    DeliveredJobReport
  >
  get copyWith =>
      _DeliveredJobReportCopyWithImpl<DeliveredJobReport, DeliveredJobReport>(
        this as DeliveredJobReport,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DeliveredJobReportMapper.ensureInitialized().stringifyValue(
      this as DeliveredJobReport,
    );
  }

  @override
  bool operator ==(Object other) {
    return DeliveredJobReportMapper.ensureInitialized().equalsValue(
      this as DeliveredJobReport,
      other,
    );
  }

  @override
  int get hashCode {
    return DeliveredJobReportMapper.ensureInitialized().hashValue(
      this as DeliveredJobReport,
    );
  }
}

extension DeliveredJobReportValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DeliveredJobReport, $Out> {
  DeliveredJobReportCopyWith<$R, DeliveredJobReport, $Out>
  get $asDeliveredJobReport => $base.as(
    (v, t, t2) => _DeliveredJobReportCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class DeliveredJobReportCopyWith<
  $R,
  $In extends DeliveredJobReport,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  MapCopyWith<$R, String, Object?, ObjectCopyWith<$R, Object?, Object?>?>
  get labelArguments;
  $R call({
    String? callId,
    String? toolName,
    bool? succeeded,
    String? body,
    int? outstanding,
    String? labelTemplate,
    Map<String, Object?>? labelArguments,
  });
  DeliveredJobReportCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _DeliveredJobReportCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DeliveredJobReport, $Out>
    implements DeliveredJobReportCopyWith<$R, DeliveredJobReport, $Out> {
  _DeliveredJobReportCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DeliveredJobReport> $mapper =
      DeliveredJobReportMapper.ensureInitialized();
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
    bool? succeeded,
    String? body,
    int? outstanding,
    String? labelTemplate,
    Map<String, Object?>? labelArguments,
  }) => $apply(
    FieldCopyWithData({
      if (callId != null) #callId: callId,
      if (toolName != null) #toolName: toolName,
      if (succeeded != null) #succeeded: succeeded,
      if (body != null) #body: body,
      if (outstanding != null) #outstanding: outstanding,
      if (labelTemplate != null) #labelTemplate: labelTemplate,
      if (labelArguments != null) #labelArguments: labelArguments,
    }),
  );
  @override
  DeliveredJobReport $make(CopyWithData data) => DeliveredJobReport(
    callId: data.get(#callId, or: $value.callId),
    toolName: data.get(#toolName, or: $value.toolName),
    succeeded: data.get(#succeeded, or: $value.succeeded),
    body: data.get(#body, or: $value.body),
    outstanding: data.get(#outstanding, or: $value.outstanding),
    labelTemplate: data.get(#labelTemplate, or: $value.labelTemplate),
    labelArguments: data.get(#labelArguments, or: $value.labelArguments),
  );

  @override
  DeliveredJobReportCopyWith<$R2, DeliveredJobReport, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DeliveredJobReportCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

