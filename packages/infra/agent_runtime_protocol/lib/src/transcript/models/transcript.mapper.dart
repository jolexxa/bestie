// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'transcript.dart';

class TranscriptMapper extends ClassMapperBase<Transcript> {
  TranscriptMapper._();

  static TranscriptMapper? _instance;
  static TranscriptMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TranscriptMapper._());
      TranscriptIdMapper.ensureInitialized();
      TranscriptEntryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Transcript';

  static TranscriptId _$id(Transcript v) => v.id;
  static const Field<Transcript, TranscriptId> _f$id = Field('id', _$id);
  static int _$revision(Transcript v) => v.revision;
  static const Field<Transcript, int> _f$revision = Field(
    'revision',
    _$revision,
  );
  static List<TranscriptEntry> _$entries(Transcript v) => v.entries;
  static const Field<Transcript, List<TranscriptEntry>> _f$entries = Field(
    'entries',
    _$entries,
  );

  @override
  final MappableFields<Transcript> fields = const {
    #id: _f$id,
    #revision: _f$revision,
    #entries: _f$entries,
  };

  static Transcript _instantiate(DecodingData data) {
    return Transcript(
      id: data.dec(_f$id),
      revision: data.dec(_f$revision),
      entries: data.dec(_f$entries),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Transcript fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Transcript>(map);
  }

  static Transcript fromJson(String json) {
    return ensureInitialized().decodeJson<Transcript>(json);
  }
}

mixin TranscriptMappable {
  String toJson() {
    return TranscriptMapper.ensureInitialized().encodeJson<Transcript>(
      this as Transcript,
    );
  }

  Map<String, dynamic> toMap() {
    return TranscriptMapper.ensureInitialized().encodeMap<Transcript>(
      this as Transcript,
    );
  }

  TranscriptCopyWith<Transcript, Transcript, Transcript> get copyWith =>
      _TranscriptCopyWithImpl<Transcript, Transcript>(
        this as Transcript,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return TranscriptMapper.ensureInitialized().stringifyValue(
      this as Transcript,
    );
  }

  @override
  bool operator ==(Object other) {
    return TranscriptMapper.ensureInitialized().equalsValue(
      this as Transcript,
      other,
    );
  }

  @override
  int get hashCode {
    return TranscriptMapper.ensureInitialized().hashValue(this as Transcript);
  }
}

extension TranscriptValueCopy<$R, $Out>
    on ObjectCopyWith<$R, Transcript, $Out> {
  TranscriptCopyWith<$R, Transcript, $Out> get $asTranscript =>
      $base.as((v, t, t2) => _TranscriptCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class TranscriptCopyWith<$R, $In extends Transcript, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  TranscriptIdCopyWith<$R, TranscriptId, TranscriptId> get id;
  ListCopyWith<
    $R,
    TranscriptEntry,
    TranscriptEntryCopyWith<$R, TranscriptEntry, TranscriptEntry>
  >
  get entries;
  $R call({TranscriptId? id, int? revision, List<TranscriptEntry>? entries});
  TranscriptCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _TranscriptCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Transcript, $Out>
    implements TranscriptCopyWith<$R, Transcript, $Out> {
  _TranscriptCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Transcript> $mapper =
      TranscriptMapper.ensureInitialized();
  @override
  TranscriptIdCopyWith<$R, TranscriptId, TranscriptId> get id =>
      $value.id.copyWith.$chain((v) => call(id: v));
  @override
  ListCopyWith<
    $R,
    TranscriptEntry,
    TranscriptEntryCopyWith<$R, TranscriptEntry, TranscriptEntry>
  >
  get entries => ListCopyWith(
    $value.entries,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(entries: v),
  );
  @override
  $R call({TranscriptId? id, int? revision, List<TranscriptEntry>? entries}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (revision != null) #revision: revision,
          if (entries != null) #entries: entries,
        }),
      );
  @override
  Transcript $make(CopyWithData data) => Transcript(
    id: data.get(#id, or: $value.id),
    revision: data.get(#revision, or: $value.revision),
    entries: data.get(#entries, or: $value.entries),
  );

  @override
  TranscriptCopyWith<$R2, Transcript, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TranscriptCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

