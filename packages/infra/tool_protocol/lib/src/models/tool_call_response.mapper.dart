// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'tool_call_response.dart';

class ToolCallResponseMapper extends ClassMapperBase<ToolCallResponse> {
  ToolCallResponseMapper._();

  static ToolCallResponseMapper? _instance;
  static ToolCallResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallResponseMapper._());
      ToolCallSucceededMapper.ensureInitialized();
      ToolCallFailedMapper.ensureInitialized();
      ToolCallCanceledMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCallResponse';

  static String _$callId(ToolCallResponse v) => v.callId;
  static const Field<ToolCallResponse, String> _f$callId = Field(
    'callId',
    _$callId,
  );
  static String _$toolName(ToolCallResponse v) => v.toolName;
  static const Field<ToolCallResponse, String> _f$toolName = Field(
    'toolName',
    _$toolName,
  );
  static int? _$elapsedMs(ToolCallResponse v) => v.elapsedMs;
  static const Field<ToolCallResponse, int> _f$elapsedMs = Field(
    'elapsedMs',
    _$elapsedMs,
    opt: true,
  );

  @override
  final MappableFields<ToolCallResponse> fields = const {
    #callId: _f$callId,
    #toolName: _f$toolName,
    #elapsedMs: _f$elapsedMs,
  };

  static ToolCallResponse _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ToolCallResponse',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCallResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCallResponse>(map);
  }

  static ToolCallResponse fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCallResponse>(json);
  }
}

mixin ToolCallResponseMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ToolCallResponseCopyWith<ToolCallResponse, ToolCallResponse, ToolCallResponse>
  get copyWith;
}

abstract class ToolCallResponseCopyWith<$R, $In extends ToolCallResponse, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? callId, String? toolName, int? elapsedMs});
  ToolCallResponseCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class ToolCallSucceededMapper extends SubClassMapperBase<ToolCallSucceeded> {
  ToolCallSucceededMapper._();

  static ToolCallSucceededMapper? _instance;
  static ToolCallSucceededMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallSucceededMapper._());
      ToolCallResponseMapper.ensureInitialized().addSubMapper(_instance!);
      ToolCallInBackgroundMapper.ensureInitialized();
      ContributionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCallSucceeded';

  static String _$callId(ToolCallSucceeded v) => v.callId;
  static const Field<ToolCallSucceeded, String> _f$callId = Field(
    'callId',
    _$callId,
  );
  static String _$toolName(ToolCallSucceeded v) => v.toolName;
  static const Field<ToolCallSucceeded, String> _f$toolName = Field(
    'toolName',
    _$toolName,
  );
  static String _$content(ToolCallSucceeded v) => v.content;
  static const Field<ToolCallSucceeded, String> _f$content = Field(
    'content',
    _$content,
  );
  static List<Contribution> _$contributions(ToolCallSucceeded v) =>
      v.contributions;
  static const Field<ToolCallSucceeded, List<Contribution>> _f$contributions =
      Field('contributions', _$contributions, opt: true, def: const []);
  static int? _$elapsedMs(ToolCallSucceeded v) => v.elapsedMs;
  static const Field<ToolCallSucceeded, int> _f$elapsedMs = Field(
    'elapsedMs',
    _$elapsedMs,
    opt: true,
  );

  @override
  final MappableFields<ToolCallSucceeded> fields = const {
    #callId: _f$callId,
    #toolName: _f$toolName,
    #content: _f$content,
    #contributions: _f$contributions,
    #elapsedMs: _f$elapsedMs,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'ok';
  @override
  late final ClassMapperBase superMapper =
      ToolCallResponseMapper.ensureInitialized();

  static ToolCallSucceeded _instantiate(DecodingData data) {
    return ToolCallSucceeded(
      callId: data.dec(_f$callId),
      toolName: data.dec(_f$toolName),
      content: data.dec(_f$content),
      contributions: data.dec(_f$contributions),
      elapsedMs: data.dec(_f$elapsedMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCallSucceeded fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCallSucceeded>(map);
  }

  static ToolCallSucceeded fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCallSucceeded>(json);
  }
}

mixin ToolCallSucceededMappable {
  String toJson() {
    return ToolCallSucceededMapper.ensureInitialized()
        .encodeJson<ToolCallSucceeded>(this as ToolCallSucceeded);
  }

  Map<String, dynamic> toMap() {
    return ToolCallSucceededMapper.ensureInitialized()
        .encodeMap<ToolCallSucceeded>(this as ToolCallSucceeded);
  }

  ToolCallSucceededCopyWith<
    ToolCallSucceeded,
    ToolCallSucceeded,
    ToolCallSucceeded
  >
  get copyWith =>
      _ToolCallSucceededCopyWithImpl<ToolCallSucceeded, ToolCallSucceeded>(
        this as ToolCallSucceeded,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ToolCallSucceededMapper.ensureInitialized().stringifyValue(
      this as ToolCallSucceeded,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolCallSucceededMapper.ensureInitialized().equalsValue(
      this as ToolCallSucceeded,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolCallSucceededMapper.ensureInitialized().hashValue(
      this as ToolCallSucceeded,
    );
  }
}

extension ToolCallSucceededValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolCallSucceeded, $Out> {
  ToolCallSucceededCopyWith<$R, ToolCallSucceeded, $Out>
  get $asToolCallSucceeded => $base.as(
    (v, t, t2) => _ToolCallSucceededCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ToolCallSucceededCopyWith<
  $R,
  $In extends ToolCallSucceeded,
  $Out
>
    implements ToolCallResponseCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    Contribution,
    ContributionCopyWith<$R, Contribution, Contribution>
  >
  get contributions;
  @override
  $R call({
    String? callId,
    String? toolName,
    String? content,
    List<Contribution>? contributions,
    int? elapsedMs,
  });
  ToolCallSucceededCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolCallSucceededCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolCallSucceeded, $Out>
    implements ToolCallSucceededCopyWith<$R, ToolCallSucceeded, $Out> {
  _ToolCallSucceededCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolCallSucceeded> $mapper =
      ToolCallSucceededMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    Contribution,
    ContributionCopyWith<$R, Contribution, Contribution>
  >
  get contributions => ListCopyWith(
    $value.contributions,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(contributions: v),
  );
  @override
  $R call({
    String? callId,
    String? toolName,
    String? content,
    List<Contribution>? contributions,
    Object? elapsedMs = $none,
  }) => $apply(
    FieldCopyWithData({
      if (callId != null) #callId: callId,
      if (toolName != null) #toolName: toolName,
      if (content != null) #content: content,
      if (contributions != null) #contributions: contributions,
      if (elapsedMs != $none) #elapsedMs: elapsedMs,
    }),
  );
  @override
  ToolCallSucceeded $make(CopyWithData data) => ToolCallSucceeded(
    callId: data.get(#callId, or: $value.callId),
    toolName: data.get(#toolName, or: $value.toolName),
    content: data.get(#content, or: $value.content),
    contributions: data.get(#contributions, or: $value.contributions),
    elapsedMs: data.get(#elapsedMs, or: $value.elapsedMs),
  );

  @override
  ToolCallSucceededCopyWith<$R2, ToolCallSucceeded, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolCallSucceededCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ToolCallInBackgroundMapper
    extends SubClassMapperBase<ToolCallInBackground> {
  ToolCallInBackgroundMapper._();

  static ToolCallInBackgroundMapper? _instance;
  static ToolCallInBackgroundMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallInBackgroundMapper._());
      ToolCallSucceededMapper.ensureInitialized().addSubMapper(_instance!);
      ContributionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCallInBackground';

  static String _$callId(ToolCallInBackground v) => v.callId;
  static const Field<ToolCallInBackground, String> _f$callId = Field(
    'callId',
    _$callId,
  );
  static String _$toolName(ToolCallInBackground v) => v.toolName;
  static const Field<ToolCallInBackground, String> _f$toolName = Field(
    'toolName',
    _$toolName,
  );
  static String _$content(ToolCallInBackground v) => v.content;
  static const Field<ToolCallInBackground, String> _f$content = Field(
    'content',
    _$content,
  );
  static List<Contribution> _$contributions(ToolCallInBackground v) =>
      v.contributions;
  static const Field<ToolCallInBackground, List<Contribution>>
  _f$contributions = Field(
    'contributions',
    _$contributions,
    opt: true,
    def: const [],
  );
  static int? _$elapsedMs(ToolCallInBackground v) => v.elapsedMs;
  static const Field<ToolCallInBackground, int> _f$elapsedMs = Field(
    'elapsedMs',
    _$elapsedMs,
    opt: true,
  );

  @override
  final MappableFields<ToolCallInBackground> fields = const {
    #callId: _f$callId,
    #toolName: _f$toolName,
    #content: _f$content,
    #contributions: _f$contributions,
    #elapsedMs: _f$elapsedMs,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'background';
  @override
  late final ClassMapperBase superMapper =
      ToolCallSucceededMapper.ensureInitialized();

  static ToolCallInBackground _instantiate(DecodingData data) {
    return ToolCallInBackground(
      callId: data.dec(_f$callId),
      toolName: data.dec(_f$toolName),
      content: data.dec(_f$content),
      contributions: data.dec(_f$contributions),
      elapsedMs: data.dec(_f$elapsedMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCallInBackground fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCallInBackground>(map);
  }

  static ToolCallInBackground fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCallInBackground>(json);
  }
}

mixin ToolCallInBackgroundMappable {
  String toJson() {
    return ToolCallInBackgroundMapper.ensureInitialized()
        .encodeJson<ToolCallInBackground>(this as ToolCallInBackground);
  }

  Map<String, dynamic> toMap() {
    return ToolCallInBackgroundMapper.ensureInitialized()
        .encodeMap<ToolCallInBackground>(this as ToolCallInBackground);
  }

  ToolCallInBackgroundCopyWith<
    ToolCallInBackground,
    ToolCallInBackground,
    ToolCallInBackground
  >
  get copyWith =>
      _ToolCallInBackgroundCopyWithImpl<
        ToolCallInBackground,
        ToolCallInBackground
      >(this as ToolCallInBackground, $identity, $identity);
  @override
  String toString() {
    return ToolCallInBackgroundMapper.ensureInitialized().stringifyValue(
      this as ToolCallInBackground,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolCallInBackgroundMapper.ensureInitialized().equalsValue(
      this as ToolCallInBackground,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolCallInBackgroundMapper.ensureInitialized().hashValue(
      this as ToolCallInBackground,
    );
  }
}

extension ToolCallInBackgroundValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolCallInBackground, $Out> {
  ToolCallInBackgroundCopyWith<$R, ToolCallInBackground, $Out>
  get $asToolCallInBackground => $base.as(
    (v, t, t2) => _ToolCallInBackgroundCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ToolCallInBackgroundCopyWith<
  $R,
  $In extends ToolCallInBackground,
  $Out
>
    implements ToolCallSucceededCopyWith<$R, $In, $Out> {
  @override
  ListCopyWith<
    $R,
    Contribution,
    ContributionCopyWith<$R, Contribution, Contribution>
  >
  get contributions;
  @override
  $R call({
    String? callId,
    String? toolName,
    String? content,
    List<Contribution>? contributions,
    int? elapsedMs,
  });
  ToolCallInBackgroundCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolCallInBackgroundCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolCallInBackground, $Out>
    implements ToolCallInBackgroundCopyWith<$R, ToolCallInBackground, $Out> {
  _ToolCallInBackgroundCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolCallInBackground> $mapper =
      ToolCallInBackgroundMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    Contribution,
    ContributionCopyWith<$R, Contribution, Contribution>
  >
  get contributions => ListCopyWith(
    $value.contributions,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(contributions: v),
  );
  @override
  $R call({
    String? callId,
    String? toolName,
    String? content,
    List<Contribution>? contributions,
    Object? elapsedMs = $none,
  }) => $apply(
    FieldCopyWithData({
      if (callId != null) #callId: callId,
      if (toolName != null) #toolName: toolName,
      if (content != null) #content: content,
      if (contributions != null) #contributions: contributions,
      if (elapsedMs != $none) #elapsedMs: elapsedMs,
    }),
  );
  @override
  ToolCallInBackground $make(CopyWithData data) => ToolCallInBackground(
    callId: data.get(#callId, or: $value.callId),
    toolName: data.get(#toolName, or: $value.toolName),
    content: data.get(#content, or: $value.content),
    contributions: data.get(#contributions, or: $value.contributions),
    elapsedMs: data.get(#elapsedMs, or: $value.elapsedMs),
  );

  @override
  ToolCallInBackgroundCopyWith<$R2, ToolCallInBackground, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ToolCallInBackgroundCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ToolCallFailedMapper extends SubClassMapperBase<ToolCallFailed> {
  ToolCallFailedMapper._();

  static ToolCallFailedMapper? _instance;
  static ToolCallFailedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallFailedMapper._());
      ToolCallResponseMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCallFailed';

  static String _$callId(ToolCallFailed v) => v.callId;
  static const Field<ToolCallFailed, String> _f$callId = Field(
    'callId',
    _$callId,
  );
  static String _$toolName(ToolCallFailed v) => v.toolName;
  static const Field<ToolCallFailed, String> _f$toolName = Field(
    'toolName',
    _$toolName,
  );
  static String _$message(ToolCallFailed v) => v.message;
  static const Field<ToolCallFailed, String> _f$message = Field(
    'message',
    _$message,
  );
  static String _$content(ToolCallFailed v) => v.content;
  static const Field<ToolCallFailed, String> _f$content = Field(
    'content',
    _$content,
    opt: true,
    def: '',
  );
  static int? _$elapsedMs(ToolCallFailed v) => v.elapsedMs;
  static const Field<ToolCallFailed, int> _f$elapsedMs = Field(
    'elapsedMs',
    _$elapsedMs,
    opt: true,
  );

  @override
  final MappableFields<ToolCallFailed> fields = const {
    #callId: _f$callId,
    #toolName: _f$toolName,
    #message: _f$message,
    #content: _f$content,
    #elapsedMs: _f$elapsedMs,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'error';
  @override
  late final ClassMapperBase superMapper =
      ToolCallResponseMapper.ensureInitialized();

  static ToolCallFailed _instantiate(DecodingData data) {
    return ToolCallFailed(
      callId: data.dec(_f$callId),
      toolName: data.dec(_f$toolName),
      message: data.dec(_f$message),
      content: data.dec(_f$content),
      elapsedMs: data.dec(_f$elapsedMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCallFailed fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCallFailed>(map);
  }

  static ToolCallFailed fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCallFailed>(json);
  }
}

mixin ToolCallFailedMappable {
  String toJson() {
    return ToolCallFailedMapper.ensureInitialized().encodeJson<ToolCallFailed>(
      this as ToolCallFailed,
    );
  }

  Map<String, dynamic> toMap() {
    return ToolCallFailedMapper.ensureInitialized().encodeMap<ToolCallFailed>(
      this as ToolCallFailed,
    );
  }

  ToolCallFailedCopyWith<ToolCallFailed, ToolCallFailed, ToolCallFailed>
  get copyWith => _ToolCallFailedCopyWithImpl<ToolCallFailed, ToolCallFailed>(
    this as ToolCallFailed,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ToolCallFailedMapper.ensureInitialized().stringifyValue(
      this as ToolCallFailed,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolCallFailedMapper.ensureInitialized().equalsValue(
      this as ToolCallFailed,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolCallFailedMapper.ensureInitialized().hashValue(
      this as ToolCallFailed,
    );
  }
}

extension ToolCallFailedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolCallFailed, $Out> {
  ToolCallFailedCopyWith<$R, ToolCallFailed, $Out> get $asToolCallFailed =>
      $base.as((v, t, t2) => _ToolCallFailedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ToolCallFailedCopyWith<$R, $In extends ToolCallFailed, $Out>
    implements ToolCallResponseCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? callId,
    String? toolName,
    String? message,
    String? content,
    int? elapsedMs,
  });
  ToolCallFailedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolCallFailedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolCallFailed, $Out>
    implements ToolCallFailedCopyWith<$R, ToolCallFailed, $Out> {
  _ToolCallFailedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolCallFailed> $mapper =
      ToolCallFailedMapper.ensureInitialized();
  @override
  $R call({
    String? callId,
    String? toolName,
    String? message,
    String? content,
    Object? elapsedMs = $none,
  }) => $apply(
    FieldCopyWithData({
      if (callId != null) #callId: callId,
      if (toolName != null) #toolName: toolName,
      if (message != null) #message: message,
      if (content != null) #content: content,
      if (elapsedMs != $none) #elapsedMs: elapsedMs,
    }),
  );
  @override
  ToolCallFailed $make(CopyWithData data) => ToolCallFailed(
    callId: data.get(#callId, or: $value.callId),
    toolName: data.get(#toolName, or: $value.toolName),
    message: data.get(#message, or: $value.message),
    content: data.get(#content, or: $value.content),
    elapsedMs: data.get(#elapsedMs, or: $value.elapsedMs),
  );

  @override
  ToolCallFailedCopyWith<$R2, ToolCallFailed, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolCallFailedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ToolCallCanceledMapper extends SubClassMapperBase<ToolCallCanceled> {
  ToolCallCanceledMapper._();

  static ToolCallCanceledMapper? _instance;
  static ToolCallCanceledMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ToolCallCanceledMapper._());
      ToolCallResponseMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ToolCallCanceled';

  static String _$callId(ToolCallCanceled v) => v.callId;
  static const Field<ToolCallCanceled, String> _f$callId = Field(
    'callId',
    _$callId,
  );
  static String _$toolName(ToolCallCanceled v) => v.toolName;
  static const Field<ToolCallCanceled, String> _f$toolName = Field(
    'toolName',
    _$toolName,
  );
  static String _$message(ToolCallCanceled v) => v.message;
  static const Field<ToolCallCanceled, String> _f$message = Field(
    'message',
    _$message,
  );
  static int? _$elapsedMs(ToolCallCanceled v) => v.elapsedMs;
  static const Field<ToolCallCanceled, int> _f$elapsedMs = Field(
    'elapsedMs',
    _$elapsedMs,
    opt: true,
  );

  @override
  final MappableFields<ToolCallCanceled> fields = const {
    #callId: _f$callId,
    #toolName: _f$toolName,
    #message: _f$message,
    #elapsedMs: _f$elapsedMs,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'canceled';
  @override
  late final ClassMapperBase superMapper =
      ToolCallResponseMapper.ensureInitialized();

  static ToolCallCanceled _instantiate(DecodingData data) {
    return ToolCallCanceled(
      callId: data.dec(_f$callId),
      toolName: data.dec(_f$toolName),
      message: data.dec(_f$message),
      elapsedMs: data.dec(_f$elapsedMs),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ToolCallCanceled fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ToolCallCanceled>(map);
  }

  static ToolCallCanceled fromJson(String json) {
    return ensureInitialized().decodeJson<ToolCallCanceled>(json);
  }
}

mixin ToolCallCanceledMappable {
  String toJson() {
    return ToolCallCanceledMapper.ensureInitialized()
        .encodeJson<ToolCallCanceled>(this as ToolCallCanceled);
  }

  Map<String, dynamic> toMap() {
    return ToolCallCanceledMapper.ensureInitialized()
        .encodeMap<ToolCallCanceled>(this as ToolCallCanceled);
  }

  ToolCallCanceledCopyWith<ToolCallCanceled, ToolCallCanceled, ToolCallCanceled>
  get copyWith =>
      _ToolCallCanceledCopyWithImpl<ToolCallCanceled, ToolCallCanceled>(
        this as ToolCallCanceled,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ToolCallCanceledMapper.ensureInitialized().stringifyValue(
      this as ToolCallCanceled,
    );
  }

  @override
  bool operator ==(Object other) {
    return ToolCallCanceledMapper.ensureInitialized().equalsValue(
      this as ToolCallCanceled,
      other,
    );
  }

  @override
  int get hashCode {
    return ToolCallCanceledMapper.ensureInitialized().hashValue(
      this as ToolCallCanceled,
    );
  }
}

extension ToolCallCanceledValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ToolCallCanceled, $Out> {
  ToolCallCanceledCopyWith<$R, ToolCallCanceled, $Out>
  get $asToolCallCanceled =>
      $base.as((v, t, t2) => _ToolCallCanceledCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ToolCallCanceledCopyWith<$R, $In extends ToolCallCanceled, $Out>
    implements ToolCallResponseCopyWith<$R, $In, $Out> {
  @override
  $R call({String? callId, String? toolName, String? message, int? elapsedMs});
  ToolCallCanceledCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ToolCallCanceledCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ToolCallCanceled, $Out>
    implements ToolCallCanceledCopyWith<$R, ToolCallCanceled, $Out> {
  _ToolCallCanceledCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ToolCallCanceled> $mapper =
      ToolCallCanceledMapper.ensureInitialized();
  @override
  $R call({
    String? callId,
    String? toolName,
    String? message,
    Object? elapsedMs = $none,
  }) => $apply(
    FieldCopyWithData({
      if (callId != null) #callId: callId,
      if (toolName != null) #toolName: toolName,
      if (message != null) #message: message,
      if (elapsedMs != $none) #elapsedMs: elapsedMs,
    }),
  );
  @override
  ToolCallCanceled $make(CopyWithData data) => ToolCallCanceled(
    callId: data.get(#callId, or: $value.callId),
    toolName: data.get(#toolName, or: $value.toolName),
    message: data.get(#message, or: $value.message),
    elapsedMs: data.get(#elapsedMs, or: $value.elapsedMs),
  );

  @override
  ToolCallCanceledCopyWith<$R2, ToolCallCanceled, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ToolCallCanceledCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

