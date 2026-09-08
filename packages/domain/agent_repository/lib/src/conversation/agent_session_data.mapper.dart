// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'agent_session_data.dart';

class AgentSessionDataMapper extends ClassMapperBase<AgentSessionData> {
  AgentSessionDataMapper._();

  static AgentSessionDataMapper? _instance;
  static AgentSessionDataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentSessionDataMapper._());
      ConversationEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AgentSessionData';

  static String _$conversationId(AgentSessionData v) => v.conversationId;
  static const Field<AgentSessionData, String> _f$conversationId = Field(
    'conversationId',
    _$conversationId,
  );
  static String _$agentId(AgentSessionData v) => v.agentId;
  static const Field<AgentSessionData, String> _f$agentId = Field(
    'agentId',
    _$agentId,
  );
  static String _$workingDirectory(AgentSessionData v) => v.workingDirectory;
  static const Field<AgentSessionData, String> _f$workingDirectory = Field(
    'workingDirectory',
    _$workingDirectory,
  );
  static DateTime _$createdAt(AgentSessionData v) => v.createdAt;
  static const Field<AgentSessionData, DateTime> _f$createdAt = Field(
    'createdAt',
    _$createdAt,
  );
  static DateTime _$updatedAt(AgentSessionData v) => v.updatedAt;
  static const Field<AgentSessionData, DateTime> _f$updatedAt = Field(
    'updatedAt',
    _$updatedAt,
  );
  static List<ConversationEntry> _$entries(AgentSessionData v) => v.entries;
  static const Field<AgentSessionData, List<ConversationEntry>> _f$entries =
      Field('entries', _$entries);

  @override
  final MappableFields<AgentSessionData> fields = const {
    #conversationId: _f$conversationId,
    #agentId: _f$agentId,
    #workingDirectory: _f$workingDirectory,
    #createdAt: _f$createdAt,
    #updatedAt: _f$updatedAt,
    #entries: _f$entries,
  };

  static AgentSessionData _instantiate(DecodingData data) {
    return AgentSessionData(
      conversationId: data.dec(_f$conversationId),
      agentId: data.dec(_f$agentId),
      workingDirectory: data.dec(_f$workingDirectory),
      createdAt: data.dec(_f$createdAt),
      updatedAt: data.dec(_f$updatedAt),
      entries: data.dec(_f$entries),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AgentSessionData fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AgentSessionData>(map);
  }

  static AgentSessionData fromJson(String json) {
    return ensureInitialized().decodeJson<AgentSessionData>(json);
  }
}

mixin AgentSessionDataMappable {
  String toJson() {
    return AgentSessionDataMapper.ensureInitialized()
        .encodeJson<AgentSessionData>(this as AgentSessionData);
  }

  Map<String, dynamic> toMap() {
    return AgentSessionDataMapper.ensureInitialized()
        .encodeMap<AgentSessionData>(this as AgentSessionData);
  }

  AgentSessionDataCopyWith<AgentSessionData, AgentSessionData, AgentSessionData>
  get copyWith =>
      _AgentSessionDataCopyWithImpl<AgentSessionData, AgentSessionData>(
        this as AgentSessionData,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AgentSessionDataMapper.ensureInitialized().stringifyValue(
      this as AgentSessionData,
    );
  }

  @override
  bool operator ==(Object other) {
    return AgentSessionDataMapper.ensureInitialized().equalsValue(
      this as AgentSessionData,
      other,
    );
  }

  @override
  int get hashCode {
    return AgentSessionDataMapper.ensureInitialized().hashValue(
      this as AgentSessionData,
    );
  }
}

extension AgentSessionDataValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AgentSessionData, $Out> {
  AgentSessionDataCopyWith<$R, AgentSessionData, $Out>
  get $asAgentSessionData =>
      $base.as((v, t, t2) => _AgentSessionDataCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AgentSessionDataCopyWith<$R, $In extends AgentSessionData, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    ConversationEntry,
    ConversationEntryCopyWith<$R, ConversationEntry, ConversationEntry>
  >
  get entries;
  $R call({
    String? conversationId,
    String? agentId,
    String? workingDirectory,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ConversationEntry>? entries,
  });
  AgentSessionDataCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AgentSessionDataCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AgentSessionData, $Out>
    implements AgentSessionDataCopyWith<$R, AgentSessionData, $Out> {
  _AgentSessionDataCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AgentSessionData> $mapper =
      AgentSessionDataMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    ConversationEntry,
    ConversationEntryCopyWith<$R, ConversationEntry, ConversationEntry>
  >
  get entries => ListCopyWith(
    $value.entries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(entries: v),
  );
  @override
  $R call({
    String? conversationId,
    String? agentId,
    String? workingDirectory,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ConversationEntry>? entries,
  }) => $apply(
    FieldCopyWithData({
      if (conversationId != null) #conversationId: conversationId,
      if (agentId != null) #agentId: agentId,
      if (workingDirectory != null) #workingDirectory: workingDirectory,
      if (createdAt != null) #createdAt: createdAt,
      if (updatedAt != null) #updatedAt: updatedAt,
      if (entries != null) #entries: entries,
    }),
  );
  @override
  AgentSessionData $make(CopyWithData data) => AgentSessionData(
    conversationId: data.get(#conversationId, or: $value.conversationId),
    agentId: data.get(#agentId, or: $value.agentId),
    workingDirectory: data.get(#workingDirectory, or: $value.workingDirectory),
    createdAt: data.get(#createdAt, or: $value.createdAt),
    updatedAt: data.get(#updatedAt, or: $value.updatedAt),
    entries: data.get(#entries, or: $value.entries),
  );

  @override
  AgentSessionDataCopyWith<$R2, AgentSessionData, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AgentSessionDataCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

