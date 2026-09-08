// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'conversation_entry.dart';

class ConversationEntryMapper extends ClassMapperBase<ConversationEntry> {
  ConversationEntryMapper._();

  static ConversationEntryMapper? _instance;
  static ConversationEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ConversationEntryMapper._());
      MessageEntryMapper.ensureInitialized();
      NoticeEntryMapper.ensureInitialized();
      ModelChangeEntryMapper.ensureInitialized();
      CompactionEntryMapper.ensureInitialized();
      JobReportEntryMapper.ensureInitialized();
      JobBackgroundedEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ConversationEntry';

  static String _$id(ConversationEntry v) => v.id;
  static const Field<ConversationEntry, String> _f$id = Field('id', _$id);
  static DateTime _$timestamp(ConversationEntry v) => v.timestamp;
  static const Field<ConversationEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );

  @override
  final MappableFields<ConversationEntry> fields = const {
    #id: _f$id,
    #timestamp: _f$timestamp,
  };

  static ConversationEntry _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ConversationEntry',
      'kind',
      '${data.value['kind']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ConversationEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ConversationEntry>(map);
  }

  static ConversationEntry fromJson(String json) {
    return ensureInitialized().decodeJson<ConversationEntry>(json);
  }
}

mixin ConversationEntryMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ConversationEntryCopyWith<
    ConversationEntry,
    ConversationEntry,
    ConversationEntry
  >
  get copyWith;
}

abstract class ConversationEntryCopyWith<
  $R,
  $In extends ConversationEntry,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? id, DateTime? timestamp});
  ConversationEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class MessageEntryMapper extends SubClassMapperBase<MessageEntry> {
  MessageEntryMapper._();

  static MessageEntryMapper? _instance;
  static MessageEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MessageEntryMapper._());
      ConversationEntryMapper.ensureInitialized().addSubMapper(_instance!);
      TranscriptEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'MessageEntry';

  static String _$id(MessageEntry v) => v.id;
  static const Field<MessageEntry, String> _f$id = Field('id', _$id);
  static DateTime _$timestamp(MessageEntry v) => v.timestamp;
  static const Field<MessageEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static TranscriptEntry _$entry(MessageEntry v) => v.entry;
  static const Field<MessageEntry, TranscriptEntry> _f$entry = Field(
    'entry',
    _$entry,
  );
  static int _$responseId(MessageEntry v) => v.responseId;
  static const Field<MessageEntry, int> _f$responseId = Field(
    'responseId',
    _$responseId,
  );

  @override
  final MappableFields<MessageEntry> fields = const {
    #id: _f$id,
    #timestamp: _f$timestamp,
    #entry: _f$entry,
    #responseId: _f$responseId,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'message';
  @override
  late final ClassMapperBase superMapper =
      ConversationEntryMapper.ensureInitialized();

  static MessageEntry _instantiate(DecodingData data) {
    return MessageEntry(
      id: data.dec(_f$id),
      timestamp: data.dec(_f$timestamp),
      entry: data.dec(_f$entry),
      responseId: data.dec(_f$responseId),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static MessageEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MessageEntry>(map);
  }

  static MessageEntry fromJson(String json) {
    return ensureInitialized().decodeJson<MessageEntry>(json);
  }
}

mixin MessageEntryMappable {
  String toJson() {
    return MessageEntryMapper.ensureInitialized().encodeJson<MessageEntry>(
      this as MessageEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return MessageEntryMapper.ensureInitialized().encodeMap<MessageEntry>(
      this as MessageEntry,
    );
  }

  MessageEntryCopyWith<MessageEntry, MessageEntry, MessageEntry> get copyWith =>
      _MessageEntryCopyWithImpl<MessageEntry, MessageEntry>(
        this as MessageEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return MessageEntryMapper.ensureInitialized().stringifyValue(
      this as MessageEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return MessageEntryMapper.ensureInitialized().equalsValue(
      this as MessageEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return MessageEntryMapper.ensureInitialized().hashValue(
      this as MessageEntry,
    );
  }
}

extension MessageEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, MessageEntry, $Out> {
  MessageEntryCopyWith<$R, MessageEntry, $Out> get $asMessageEntry =>
      $base.as((v, t, t2) => _MessageEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MessageEntryCopyWith<$R, $In extends MessageEntry, $Out>
    implements ConversationEntryCopyWith<$R, $In, $Out> {
  TranscriptEntryCopyWith<$R, TranscriptEntry, TranscriptEntry> get entry;
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    TranscriptEntry? entry,
    int? responseId,
  });
  MessageEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _MessageEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, MessageEntry, $Out>
    implements MessageEntryCopyWith<$R, MessageEntry, $Out> {
  _MessageEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MessageEntry> $mapper =
      MessageEntryMapper.ensureInitialized();
  @override
  TranscriptEntryCopyWith<$R, TranscriptEntry, TranscriptEntry> get entry =>
      $value.entry.copyWith.$chain((v) => call(entry: v));
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    TranscriptEntry? entry,
    int? responseId,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (timestamp != null) #timestamp: timestamp,
      if (entry != null) #entry: entry,
      if (responseId != null) #responseId: responseId,
    }),
  );
  @override
  MessageEntry $make(CopyWithData data) => MessageEntry(
    id: data.get(#id, or: $value.id),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    entry: data.get(#entry, or: $value.entry),
    responseId: data.get(#responseId, or: $value.responseId),
  );

  @override
  MessageEntryCopyWith<$R2, MessageEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _MessageEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class NoticeEntryMapper extends SubClassMapperBase<NoticeEntry> {
  NoticeEntryMapper._();

  static NoticeEntryMapper? _instance;
  static NoticeEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = NoticeEntryMapper._());
      ConversationEntryMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'NoticeEntry';

  static String _$id(NoticeEntry v) => v.id;
  static const Field<NoticeEntry, String> _f$id = Field('id', _$id);
  static DateTime _$timestamp(NoticeEntry v) => v.timestamp;
  static const Field<NoticeEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static String _$text(NoticeEntry v) => v.text;
  static const Field<NoticeEntry, String> _f$text = Field('text', _$text);

  @override
  final MappableFields<NoticeEntry> fields = const {
    #id: _f$id,
    #timestamp: _f$timestamp,
    #text: _f$text,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'notice';
  @override
  late final ClassMapperBase superMapper =
      ConversationEntryMapper.ensureInitialized();

  static NoticeEntry _instantiate(DecodingData data) {
    return NoticeEntry(
      id: data.dec(_f$id),
      timestamp: data.dec(_f$timestamp),
      text: data.dec(_f$text),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static NoticeEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<NoticeEntry>(map);
  }

  static NoticeEntry fromJson(String json) {
    return ensureInitialized().decodeJson<NoticeEntry>(json);
  }
}

mixin NoticeEntryMappable {
  String toJson() {
    return NoticeEntryMapper.ensureInitialized().encodeJson<NoticeEntry>(
      this as NoticeEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return NoticeEntryMapper.ensureInitialized().encodeMap<NoticeEntry>(
      this as NoticeEntry,
    );
  }

  NoticeEntryCopyWith<NoticeEntry, NoticeEntry, NoticeEntry> get copyWith =>
      _NoticeEntryCopyWithImpl<NoticeEntry, NoticeEntry>(
        this as NoticeEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return NoticeEntryMapper.ensureInitialized().stringifyValue(
      this as NoticeEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return NoticeEntryMapper.ensureInitialized().equalsValue(
      this as NoticeEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return NoticeEntryMapper.ensureInitialized().hashValue(this as NoticeEntry);
  }
}

extension NoticeEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, NoticeEntry, $Out> {
  NoticeEntryCopyWith<$R, NoticeEntry, $Out> get $asNoticeEntry =>
      $base.as((v, t, t2) => _NoticeEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class NoticeEntryCopyWith<$R, $In extends NoticeEntry, $Out>
    implements ConversationEntryCopyWith<$R, $In, $Out> {
  @override
  $R call({String? id, DateTime? timestamp, String? text});
  NoticeEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _NoticeEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, NoticeEntry, $Out>
    implements NoticeEntryCopyWith<$R, NoticeEntry, $Out> {
  _NoticeEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<NoticeEntry> $mapper =
      NoticeEntryMapper.ensureInitialized();
  @override
  $R call({String? id, DateTime? timestamp, String? text}) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (timestamp != null) #timestamp: timestamp,
      if (text != null) #text: text,
    }),
  );
  @override
  NoticeEntry $make(CopyWithData data) => NoticeEntry(
    id: data.get(#id, or: $value.id),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    text: data.get(#text, or: $value.text),
  );

  @override
  NoticeEntryCopyWith<$R2, NoticeEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _NoticeEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelChangeEntryMapper extends SubClassMapperBase<ModelChangeEntry> {
  ModelChangeEntryMapper._();

  static ModelChangeEntryMapper? _instance;
  static ModelChangeEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelChangeEntryMapper._());
      ConversationEntryMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ModelChangeEntry';

  static String _$id(ModelChangeEntry v) => v.id;
  static const Field<ModelChangeEntry, String> _f$id = Field('id', _$id);
  static DateTime _$timestamp(ModelChangeEntry v) => v.timestamp;
  static const Field<ModelChangeEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static String _$modelId(ModelChangeEntry v) => v.modelId;
  static const Field<ModelChangeEntry, String> _f$modelId = Field(
    'modelId',
    _$modelId,
  );
  static String _$displayName(ModelChangeEntry v) => v.displayName;
  static const Field<ModelChangeEntry, String> _f$displayName = Field(
    'displayName',
    _$displayName,
  );
  static int _$contextSize(ModelChangeEntry v) => v.contextSize;
  static const Field<ModelChangeEntry, int> _f$contextSize = Field(
    'contextSize',
    _$contextSize,
  );
  static String _$provider(ModelChangeEntry v) => v.provider;
  static const Field<ModelChangeEntry, String> _f$provider = Field(
    'provider',
    _$provider,
    opt: true,
    def: ModelChangeEntry.legacyModelProvider,
  );

  @override
  final MappableFields<ModelChangeEntry> fields = const {
    #id: _f$id,
    #timestamp: _f$timestamp,
    #modelId: _f$modelId,
    #displayName: _f$displayName,
    #contextSize: _f$contextSize,
    #provider: _f$provider,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'model_change';
  @override
  late final ClassMapperBase superMapper =
      ConversationEntryMapper.ensureInitialized();

  static ModelChangeEntry _instantiate(DecodingData data) {
    return ModelChangeEntry(
      id: data.dec(_f$id),
      timestamp: data.dec(_f$timestamp),
      modelId: data.dec(_f$modelId),
      displayName: data.dec(_f$displayName),
      contextSize: data.dec(_f$contextSize),
      provider: data.dec(_f$provider),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ModelChangeEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelChangeEntry>(map);
  }

  static ModelChangeEntry fromJson(String json) {
    return ensureInitialized().decodeJson<ModelChangeEntry>(json);
  }
}

mixin ModelChangeEntryMappable {
  String toJson() {
    return ModelChangeEntryMapper.ensureInitialized()
        .encodeJson<ModelChangeEntry>(this as ModelChangeEntry);
  }

  Map<String, dynamic> toMap() {
    return ModelChangeEntryMapper.ensureInitialized()
        .encodeMap<ModelChangeEntry>(this as ModelChangeEntry);
  }

  ModelChangeEntryCopyWith<ModelChangeEntry, ModelChangeEntry, ModelChangeEntry>
  get copyWith =>
      _ModelChangeEntryCopyWithImpl<ModelChangeEntry, ModelChangeEntry>(
        this as ModelChangeEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelChangeEntryMapper.ensureInitialized().stringifyValue(
      this as ModelChangeEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelChangeEntryMapper.ensureInitialized().equalsValue(
      this as ModelChangeEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelChangeEntryMapper.ensureInitialized().hashValue(
      this as ModelChangeEntry,
    );
  }
}

extension ModelChangeEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelChangeEntry, $Out> {
  ModelChangeEntryCopyWith<$R, ModelChangeEntry, $Out>
  get $asModelChangeEntry =>
      $base.as((v, t, t2) => _ModelChangeEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelChangeEntryCopyWith<$R, $In extends ModelChangeEntry, $Out>
    implements ConversationEntryCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    String? modelId,
    String? displayName,
    int? contextSize,
    String? provider,
  });
  ModelChangeEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelChangeEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelChangeEntry, $Out>
    implements ModelChangeEntryCopyWith<$R, ModelChangeEntry, $Out> {
  _ModelChangeEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelChangeEntry> $mapper =
      ModelChangeEntryMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    String? modelId,
    String? displayName,
    int? contextSize,
    String? provider,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (timestamp != null) #timestamp: timestamp,
      if (modelId != null) #modelId: modelId,
      if (displayName != null) #displayName: displayName,
      if (contextSize != null) #contextSize: contextSize,
      if (provider != null) #provider: provider,
    }),
  );
  @override
  ModelChangeEntry $make(CopyWithData data) => ModelChangeEntry(
    id: data.get(#id, or: $value.id),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    modelId: data.get(#modelId, or: $value.modelId),
    displayName: data.get(#displayName, or: $value.displayName),
    contextSize: data.get(#contextSize, or: $value.contextSize),
    provider: data.get(#provider, or: $value.provider),
  );

  @override
  ModelChangeEntryCopyWith<$R2, ModelChangeEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelChangeEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CompactionEntryMapper extends SubClassMapperBase<CompactionEntry> {
  CompactionEntryMapper._();

  static CompactionEntryMapper? _instance;
  static CompactionEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CompactionEntryMapper._());
      ConversationEntryMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'CompactionEntry';

  static String _$id(CompactionEntry v) => v.id;
  static const Field<CompactionEntry, String> _f$id = Field('id', _$id);
  static DateTime _$timestamp(CompactionEntry v) => v.timestamp;
  static const Field<CompactionEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static String _$summary(CompactionEntry v) => v.summary;
  static const Field<CompactionEntry, String> _f$summary = Field(
    'summary',
    _$summary,
  );
  static int _$tokensBefore(CompactionEntry v) => v.tokensBefore;
  static const Field<CompactionEntry, int> _f$tokensBefore = Field(
    'tokensBefore',
    _$tokensBefore,
  );

  @override
  final MappableFields<CompactionEntry> fields = const {
    #id: _f$id,
    #timestamp: _f$timestamp,
    #summary: _f$summary,
    #tokensBefore: _f$tokensBefore,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'compaction';
  @override
  late final ClassMapperBase superMapper =
      ConversationEntryMapper.ensureInitialized();

  static CompactionEntry _instantiate(DecodingData data) {
    return CompactionEntry(
      id: data.dec(_f$id),
      timestamp: data.dec(_f$timestamp),
      summary: data.dec(_f$summary),
      tokensBefore: data.dec(_f$tokensBefore),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CompactionEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CompactionEntry>(map);
  }

  static CompactionEntry fromJson(String json) {
    return ensureInitialized().decodeJson<CompactionEntry>(json);
  }
}

mixin CompactionEntryMappable {
  String toJson() {
    return CompactionEntryMapper.ensureInitialized()
        .encodeJson<CompactionEntry>(this as CompactionEntry);
  }

  Map<String, dynamic> toMap() {
    return CompactionEntryMapper.ensureInitialized().encodeMap<CompactionEntry>(
      this as CompactionEntry,
    );
  }

  CompactionEntryCopyWith<CompactionEntry, CompactionEntry, CompactionEntry>
  get copyWith =>
      _CompactionEntryCopyWithImpl<CompactionEntry, CompactionEntry>(
        this as CompactionEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CompactionEntryMapper.ensureInitialized().stringifyValue(
      this as CompactionEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return CompactionEntryMapper.ensureInitialized().equalsValue(
      this as CompactionEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return CompactionEntryMapper.ensureInitialized().hashValue(
      this as CompactionEntry,
    );
  }
}

extension CompactionEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CompactionEntry, $Out> {
  CompactionEntryCopyWith<$R, CompactionEntry, $Out> get $asCompactionEntry =>
      $base.as((v, t, t2) => _CompactionEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CompactionEntryCopyWith<$R, $In extends CompactionEntry, $Out>
    implements ConversationEntryCopyWith<$R, $In, $Out> {
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    String? summary,
    int? tokensBefore,
  });
  CompactionEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CompactionEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CompactionEntry, $Out>
    implements CompactionEntryCopyWith<$R, CompactionEntry, $Out> {
  _CompactionEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CompactionEntry> $mapper =
      CompactionEntryMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    String? summary,
    int? tokensBefore,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (timestamp != null) #timestamp: timestamp,
      if (summary != null) #summary: summary,
      if (tokensBefore != null) #tokensBefore: tokensBefore,
    }),
  );
  @override
  CompactionEntry $make(CopyWithData data) => CompactionEntry(
    id: data.get(#id, or: $value.id),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    summary: data.get(#summary, or: $value.summary),
    tokensBefore: data.get(#tokensBefore, or: $value.tokensBefore),
  );

  @override
  CompactionEntryCopyWith<$R2, CompactionEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CompactionEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class JobReportEntryMapper extends SubClassMapperBase<JobReportEntry> {
  JobReportEntryMapper._();

  static JobReportEntryMapper? _instance;
  static JobReportEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JobReportEntryMapper._());
      ConversationEntryMapper.ensureInitialized().addSubMapper(_instance!);
      DeliveredJobReportMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'JobReportEntry';

  static String _$id(JobReportEntry v) => v.id;
  static const Field<JobReportEntry, String> _f$id = Field('id', _$id);
  static DateTime _$timestamp(JobReportEntry v) => v.timestamp;
  static const Field<JobReportEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static int _$responseId(JobReportEntry v) => v.responseId;
  static const Field<JobReportEntry, int> _f$responseId = Field(
    'responseId',
    _$responseId,
  );
  static List<DeliveredJobReport> _$reports(JobReportEntry v) => v.reports;
  static const Field<JobReportEntry, List<DeliveredJobReport>> _f$reports =
      Field('reports', _$reports);

  @override
  final MappableFields<JobReportEntry> fields = const {
    #id: _f$id,
    #timestamp: _f$timestamp,
    #responseId: _f$responseId,
    #reports: _f$reports,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'job_report';
  @override
  late final ClassMapperBase superMapper =
      ConversationEntryMapper.ensureInitialized();

  static JobReportEntry _instantiate(DecodingData data) {
    return JobReportEntry(
      id: data.dec(_f$id),
      timestamp: data.dec(_f$timestamp),
      responseId: data.dec(_f$responseId),
      reports: data.dec(_f$reports),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JobReportEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JobReportEntry>(map);
  }

  static JobReportEntry fromJson(String json) {
    return ensureInitialized().decodeJson<JobReportEntry>(json);
  }
}

mixin JobReportEntryMappable {
  String toJson() {
    return JobReportEntryMapper.ensureInitialized().encodeJson<JobReportEntry>(
      this as JobReportEntry,
    );
  }

  Map<String, dynamic> toMap() {
    return JobReportEntryMapper.ensureInitialized().encodeMap<JobReportEntry>(
      this as JobReportEntry,
    );
  }

  JobReportEntryCopyWith<JobReportEntry, JobReportEntry, JobReportEntry>
  get copyWith => _JobReportEntryCopyWithImpl<JobReportEntry, JobReportEntry>(
    this as JobReportEntry,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return JobReportEntryMapper.ensureInitialized().stringifyValue(
      this as JobReportEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return JobReportEntryMapper.ensureInitialized().equalsValue(
      this as JobReportEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return JobReportEntryMapper.ensureInitialized().hashValue(
      this as JobReportEntry,
    );
  }
}

extension JobReportEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JobReportEntry, $Out> {
  JobReportEntryCopyWith<$R, JobReportEntry, $Out> get $asJobReportEntry =>
      $base.as((v, t, t2) => _JobReportEntryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class JobReportEntryCopyWith<$R, $In extends JobReportEntry, $Out>
    implements ConversationEntryCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    DeliveredJobReport,
    DeliveredJobReportCopyWith<$R, DeliveredJobReport, DeliveredJobReport>
  >
  get reports;
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    int? responseId,
    List<DeliveredJobReport>? reports,
  });
  JobReportEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _JobReportEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JobReportEntry, $Out>
    implements JobReportEntryCopyWith<$R, JobReportEntry, $Out> {
  _JobReportEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JobReportEntry> $mapper =
      JobReportEntryMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    DeliveredJobReport,
    DeliveredJobReportCopyWith<$R, DeliveredJobReport, DeliveredJobReport>
  >
  get reports => ListCopyWith(
    $value.reports,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(reports: v),
  );
  @override
  $R call({
    String? id,
    DateTime? timestamp,
    int? responseId,
    List<DeliveredJobReport>? reports,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (timestamp != null) #timestamp: timestamp,
      if (responseId != null) #responseId: responseId,
      if (reports != null) #reports: reports,
    }),
  );
  @override
  JobReportEntry $make(CopyWithData data) => JobReportEntry(
    id: data.get(#id, or: $value.id),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    responseId: data.get(#responseId, or: $value.responseId),
    reports: data.get(#reports, or: $value.reports),
  );

  @override
  JobReportEntryCopyWith<$R2, JobReportEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _JobReportEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class JobBackgroundedEntryMapper
    extends SubClassMapperBase<JobBackgroundedEntry> {
  JobBackgroundedEntryMapper._();

  static JobBackgroundedEntryMapper? _instance;
  static JobBackgroundedEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = JobBackgroundedEntryMapper._());
      ConversationEntryMapper.ensureInitialized().addSubMapper(_instance!);
      JobInBackgroundMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'JobBackgroundedEntry';

  static String _$id(JobBackgroundedEntry v) => v.id;
  static const Field<JobBackgroundedEntry, String> _f$id = Field('id', _$id);
  static DateTime _$timestamp(JobBackgroundedEntry v) => v.timestamp;
  static const Field<JobBackgroundedEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static JobInBackground _$job(JobBackgroundedEntry v) => v.job;
  static const Field<JobBackgroundedEntry, JobInBackground> _f$job = Field(
    'job',
    _$job,
  );

  @override
  final MappableFields<JobBackgroundedEntry> fields = const {
    #id: _f$id,
    #timestamp: _f$timestamp,
    #job: _f$job,
  };

  @override
  final String discriminatorKey = 'kind';
  @override
  final dynamic discriminatorValue = 'job_backgrounded';
  @override
  late final ClassMapperBase superMapper =
      ConversationEntryMapper.ensureInitialized();

  static JobBackgroundedEntry _instantiate(DecodingData data) {
    return JobBackgroundedEntry(
      id: data.dec(_f$id),
      timestamp: data.dec(_f$timestamp),
      job: data.dec(_f$job),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static JobBackgroundedEntry fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<JobBackgroundedEntry>(map);
  }

  static JobBackgroundedEntry fromJson(String json) {
    return ensureInitialized().decodeJson<JobBackgroundedEntry>(json);
  }
}

mixin JobBackgroundedEntryMappable {
  String toJson() {
    return JobBackgroundedEntryMapper.ensureInitialized()
        .encodeJson<JobBackgroundedEntry>(this as JobBackgroundedEntry);
  }

  Map<String, dynamic> toMap() {
    return JobBackgroundedEntryMapper.ensureInitialized()
        .encodeMap<JobBackgroundedEntry>(this as JobBackgroundedEntry);
  }

  JobBackgroundedEntryCopyWith<
    JobBackgroundedEntry,
    JobBackgroundedEntry,
    JobBackgroundedEntry
  >
  get copyWith =>
      _JobBackgroundedEntryCopyWithImpl<
        JobBackgroundedEntry,
        JobBackgroundedEntry
      >(this as JobBackgroundedEntry, $identity, $identity);
  @override
  String toString() {
    return JobBackgroundedEntryMapper.ensureInitialized().stringifyValue(
      this as JobBackgroundedEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return JobBackgroundedEntryMapper.ensureInitialized().equalsValue(
      this as JobBackgroundedEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return JobBackgroundedEntryMapper.ensureInitialized().hashValue(
      this as JobBackgroundedEntry,
    );
  }
}

extension JobBackgroundedEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, JobBackgroundedEntry, $Out> {
  JobBackgroundedEntryCopyWith<$R, JobBackgroundedEntry, $Out>
  get $asJobBackgroundedEntry => $base.as(
    (v, t, t2) => _JobBackgroundedEntryCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class JobBackgroundedEntryCopyWith<
  $R,
  $In extends JobBackgroundedEntry,
  $Out
>
    implements ConversationEntryCopyWith<$R, $In, $Out> {
  JobInBackgroundCopyWith<$R, JobInBackground, JobInBackground> get job;
  @override
  $R call({String? id, DateTime? timestamp, JobInBackground? job});
  JobBackgroundedEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _JobBackgroundedEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, JobBackgroundedEntry, $Out>
    implements JobBackgroundedEntryCopyWith<$R, JobBackgroundedEntry, $Out> {
  _JobBackgroundedEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<JobBackgroundedEntry> $mapper =
      JobBackgroundedEntryMapper.ensureInitialized();
  @override
  JobInBackgroundCopyWith<$R, JobInBackground, JobInBackground> get job =>
      $value.job.copyWith.$chain((v) => call(job: v));
  @override
  $R call({String? id, DateTime? timestamp, JobInBackground? job}) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (timestamp != null) #timestamp: timestamp,
      if (job != null) #job: job,
    }),
  );
  @override
  JobBackgroundedEntry $make(CopyWithData data) => JobBackgroundedEntry(
    id: data.get(#id, or: $value.id),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    job: data.get(#job, or: $value.job),
  );

  @override
  JobBackgroundedEntryCopyWith<$R2, JobBackgroundedEntry, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _JobBackgroundedEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

