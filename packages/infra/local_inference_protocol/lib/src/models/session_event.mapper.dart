// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'session_event.dart';

class SessionEventMapper extends ClassMapperBase<SessionEvent> {
  SessionEventMapper._();

  static SessionEventMapper? _instance;
  static SessionEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SessionEventMapper._());
      SessionOpenedMapper.ensureInitialized();
      PoolSnapshotEventMapper.ensureInitialized();
      ModelStatusEventMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SessionEvent';

  @override
  final MappableFields<SessionEvent> fields = const {};

  static SessionEvent _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'SessionEvent',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SessionEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SessionEvent>(map);
  }

  static SessionEvent fromJson(String json) {
    return ensureInitialized().decodeJson<SessionEvent>(json);
  }
}

mixin SessionEventMappable {
  String toJson();
  Map<String, dynamic> toMap();
  SessionEventCopyWith<SessionEvent, SessionEvent, SessionEvent> get copyWith;
}

abstract class SessionEventCopyWith<$R, $In extends SessionEvent, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  SessionEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class SessionOpenedMapper extends SubClassMapperBase<SessionOpened> {
  SessionOpenedMapper._();

  static SessionOpenedMapper? _instance;
  static SessionOpenedMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SessionOpenedMapper._());
      SessionEventMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'SessionOpened';

  static String _$ownerToken(SessionOpened v) => v.ownerToken;
  static const Field<SessionOpened, String> _f$ownerToken = Field(
    'ownerToken',
    _$ownerToken,
    key: r'owner_token',
  );

  @override
  final MappableFields<SessionOpened> fields = const {
    #ownerToken: _f$ownerToken,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'session_opened';
  @override
  late final ClassMapperBase superMapper =
      SessionEventMapper.ensureInitialized();

  static SessionOpened _instantiate(DecodingData data) {
    return SessionOpened(ownerToken: data.dec(_f$ownerToken));
  }

  @override
  final Function instantiate = _instantiate;

  static SessionOpened fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SessionOpened>(map);
  }

  static SessionOpened fromJson(String json) {
    return ensureInitialized().decodeJson<SessionOpened>(json);
  }
}

mixin SessionOpenedMappable {
  String toJson() {
    return SessionOpenedMapper.ensureInitialized().encodeJson<SessionOpened>(
      this as SessionOpened,
    );
  }

  Map<String, dynamic> toMap() {
    return SessionOpenedMapper.ensureInitialized().encodeMap<SessionOpened>(
      this as SessionOpened,
    );
  }

  SessionOpenedCopyWith<SessionOpened, SessionOpened, SessionOpened>
  get copyWith => _SessionOpenedCopyWithImpl<SessionOpened, SessionOpened>(
    this as SessionOpened,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SessionOpenedMapper.ensureInitialized().stringifyValue(
      this as SessionOpened,
    );
  }

  @override
  bool operator ==(Object other) {
    return SessionOpenedMapper.ensureInitialized().equalsValue(
      this as SessionOpened,
      other,
    );
  }

  @override
  int get hashCode {
    return SessionOpenedMapper.ensureInitialized().hashValue(
      this as SessionOpened,
    );
  }
}

extension SessionOpenedValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SessionOpened, $Out> {
  SessionOpenedCopyWith<$R, SessionOpened, $Out> get $asSessionOpened =>
      $base.as((v, t, t2) => _SessionOpenedCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SessionOpenedCopyWith<$R, $In extends SessionOpened, $Out>
    implements SessionEventCopyWith<$R, $In, $Out> {
  @override
  $R call({String? ownerToken});
  SessionOpenedCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _SessionOpenedCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SessionOpened, $Out>
    implements SessionOpenedCopyWith<$R, SessionOpened, $Out> {
  _SessionOpenedCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SessionOpened> $mapper =
      SessionOpenedMapper.ensureInitialized();
  @override
  $R call({String? ownerToken}) => $apply(
    FieldCopyWithData({if (ownerToken != null) #ownerToken: ownerToken}),
  );
  @override
  SessionOpened $make(CopyWithData data) =>
      SessionOpened(ownerToken: data.get(#ownerToken, or: $value.ownerToken));

  @override
  SessionOpenedCopyWith<$R2, SessionOpened, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SessionOpenedCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PoolSnapshotEventMapper extends SubClassMapperBase<PoolSnapshotEvent> {
  PoolSnapshotEventMapper._();

  static PoolSnapshotEventMapper? _instance;
  static PoolSnapshotEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PoolSnapshotEventMapper._());
      SessionEventMapper.ensureInitialized().addSubMapper(_instance!);
      PoolAgentMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PoolSnapshotEvent';

  static int _$contextSize(PoolSnapshotEvent v) => v.contextSize;
  static const Field<PoolSnapshotEvent, int> _f$contextSize = Field(
    'contextSize',
    _$contextSize,
    key: r'context_size',
  );
  static int _$maxAgents(PoolSnapshotEvent v) => v.maxAgents;
  static const Field<PoolSnapshotEvent, int> _f$maxAgents = Field(
    'maxAgents',
    _$maxAgents,
    key: r'max_agents',
  );
  static List<PoolAgent> _$agents(PoolSnapshotEvent v) => v.agents;
  static const Field<PoolSnapshotEvent, List<PoolAgent>> _f$agents = Field(
    'agents',
    _$agents,
  );
  static int _$borrowedTokens(PoolSnapshotEvent v) => v.borrowedTokens;
  static const Field<PoolSnapshotEvent, int> _f$borrowedTokens = Field(
    'borrowedTokens',
    _$borrowedTokens,
    key: r'borrowed_tokens',
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<PoolSnapshotEvent> fields = const {
    #contextSize: _f$contextSize,
    #maxAgents: _f$maxAgents,
    #agents: _f$agents,
    #borrowedTokens: _f$borrowedTokens,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'pool_snapshot';
  @override
  late final ClassMapperBase superMapper =
      SessionEventMapper.ensureInitialized();

  static PoolSnapshotEvent _instantiate(DecodingData data) {
    return PoolSnapshotEvent(
      contextSize: data.dec(_f$contextSize),
      maxAgents: data.dec(_f$maxAgents),
      agents: data.dec(_f$agents),
      borrowedTokens: data.dec(_f$borrowedTokens),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PoolSnapshotEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PoolSnapshotEvent>(map);
  }

  static PoolSnapshotEvent fromJson(String json) {
    return ensureInitialized().decodeJson<PoolSnapshotEvent>(json);
  }
}

mixin PoolSnapshotEventMappable {
  String toJson() {
    return PoolSnapshotEventMapper.ensureInitialized()
        .encodeJson<PoolSnapshotEvent>(this as PoolSnapshotEvent);
  }

  Map<String, dynamic> toMap() {
    return PoolSnapshotEventMapper.ensureInitialized()
        .encodeMap<PoolSnapshotEvent>(this as PoolSnapshotEvent);
  }

  PoolSnapshotEventCopyWith<
    PoolSnapshotEvent,
    PoolSnapshotEvent,
    PoolSnapshotEvent
  >
  get copyWith =>
      _PoolSnapshotEventCopyWithImpl<PoolSnapshotEvent, PoolSnapshotEvent>(
        this as PoolSnapshotEvent,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PoolSnapshotEventMapper.ensureInitialized().stringifyValue(
      this as PoolSnapshotEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return PoolSnapshotEventMapper.ensureInitialized().equalsValue(
      this as PoolSnapshotEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return PoolSnapshotEventMapper.ensureInitialized().hashValue(
      this as PoolSnapshotEvent,
    );
  }
}

extension PoolSnapshotEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PoolSnapshotEvent, $Out> {
  PoolSnapshotEventCopyWith<$R, PoolSnapshotEvent, $Out>
  get $asPoolSnapshotEvent => $base.as(
    (v, t, t2) => _PoolSnapshotEventCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PoolSnapshotEventCopyWith<
  $R,
  $In extends PoolSnapshotEvent,
  $Out
>
    implements SessionEventCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, PoolAgent, PoolAgentCopyWith<$R, PoolAgent, PoolAgent>>
  get agents;
  @override
  $R call({
    int? contextSize,
    int? maxAgents,
    List<PoolAgent>? agents,
    int? borrowedTokens,
  });
  PoolSnapshotEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PoolSnapshotEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PoolSnapshotEvent, $Out>
    implements PoolSnapshotEventCopyWith<$R, PoolSnapshotEvent, $Out> {
  _PoolSnapshotEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PoolSnapshotEvent> $mapper =
      PoolSnapshotEventMapper.ensureInitialized();
  @override
  ListCopyWith<$R, PoolAgent, PoolAgentCopyWith<$R, PoolAgent, PoolAgent>>
  get agents => ListCopyWith(
    $value.agents,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(agents: v),
  );
  @override
  $R call({
    int? contextSize,
    int? maxAgents,
    List<PoolAgent>? agents,
    int? borrowedTokens,
  }) => $apply(
    FieldCopyWithData({
      if (contextSize != null) #contextSize: contextSize,
      if (maxAgents != null) #maxAgents: maxAgents,
      if (agents != null) #agents: agents,
      if (borrowedTokens != null) #borrowedTokens: borrowedTokens,
    }),
  );
  @override
  PoolSnapshotEvent $make(CopyWithData data) => PoolSnapshotEvent(
    contextSize: data.get(#contextSize, or: $value.contextSize),
    maxAgents: data.get(#maxAgents, or: $value.maxAgents),
    agents: data.get(#agents, or: $value.agents),
    borrowedTokens: data.get(#borrowedTokens, or: $value.borrowedTokens),
  );

  @override
  PoolSnapshotEventCopyWith<$R2, PoolSnapshotEvent, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PoolSnapshotEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PoolAgentMapper extends ClassMapperBase<PoolAgent> {
  PoolAgentMapper._();

  static PoolAgentMapper? _instance;
  static PoolAgentMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PoolAgentMapper._());
      AgentLeaseKindMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PoolAgent';

  static String _$id(PoolAgent v) => v.id;
  static const Field<PoolAgent, String> _f$id = Field('id', _$id);
  static AgentLeaseKind _$kind(PoolAgent v) => v.kind;
  static const Field<PoolAgent, AgentLeaseKind> _f$kind = Field('kind', _$kind);
  static int _$claimedTokens(PoolAgent v) => v.claimedTokens;
  static const Field<PoolAgent, int> _f$claimedTokens = Field(
    'claimedTokens',
    _$claimedTokens,
    key: r'claimed_tokens',
  );
  static int _$usedTokens(PoolAgent v) => v.usedTokens;
  static const Field<PoolAgent, int> _f$usedTokens = Field(
    'usedTokens',
    _$usedTokens,
    key: r'used_tokens',
  );

  @override
  final MappableFields<PoolAgent> fields = const {
    #id: _f$id,
    #kind: _f$kind,
    #claimedTokens: _f$claimedTokens,
    #usedTokens: _f$usedTokens,
  };

  static PoolAgent _instantiate(DecodingData data) {
    return PoolAgent(
      id: data.dec(_f$id),
      kind: data.dec(_f$kind),
      claimedTokens: data.dec(_f$claimedTokens),
      usedTokens: data.dec(_f$usedTokens),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PoolAgent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PoolAgent>(map);
  }

  static PoolAgent fromJson(String json) {
    return ensureInitialized().decodeJson<PoolAgent>(json);
  }
}

mixin PoolAgentMappable {
  String toJson() {
    return PoolAgentMapper.ensureInitialized().encodeJson<PoolAgent>(
      this as PoolAgent,
    );
  }

  Map<String, dynamic> toMap() {
    return PoolAgentMapper.ensureInitialized().encodeMap<PoolAgent>(
      this as PoolAgent,
    );
  }

  PoolAgentCopyWith<PoolAgent, PoolAgent, PoolAgent> get copyWith =>
      _PoolAgentCopyWithImpl<PoolAgent, PoolAgent>(
        this as PoolAgent,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PoolAgentMapper.ensureInitialized().stringifyValue(
      this as PoolAgent,
    );
  }

  @override
  bool operator ==(Object other) {
    return PoolAgentMapper.ensureInitialized().equalsValue(
      this as PoolAgent,
      other,
    );
  }

  @override
  int get hashCode {
    return PoolAgentMapper.ensureInitialized().hashValue(this as PoolAgent);
  }
}

extension PoolAgentValueCopy<$R, $Out> on ObjectCopyWith<$R, PoolAgent, $Out> {
  PoolAgentCopyWith<$R, PoolAgent, $Out> get $asPoolAgent =>
      $base.as((v, t, t2) => _PoolAgentCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PoolAgentCopyWith<$R, $In extends PoolAgent, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    AgentLeaseKind? kind,
    int? claimedTokens,
    int? usedTokens,
  });
  PoolAgentCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PoolAgentCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PoolAgent, $Out>
    implements PoolAgentCopyWith<$R, PoolAgent, $Out> {
  _PoolAgentCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PoolAgent> $mapper =
      PoolAgentMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    AgentLeaseKind? kind,
    int? claimedTokens,
    int? usedTokens,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (kind != null) #kind: kind,
      if (claimedTokens != null) #claimedTokens: claimedTokens,
      if (usedTokens != null) #usedTokens: usedTokens,
    }),
  );
  @override
  PoolAgent $make(CopyWithData data) => PoolAgent(
    id: data.get(#id, or: $value.id),
    kind: data.get(#kind, or: $value.kind),
    claimedTokens: data.get(#claimedTokens, or: $value.claimedTokens),
    usedTokens: data.get(#usedTokens, or: $value.usedTokens),
  );

  @override
  PoolAgentCopyWith<$R2, PoolAgent, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PoolAgentCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ModelStatusEventMapper extends SubClassMapperBase<ModelStatusEvent> {
  ModelStatusEventMapper._();

  static ModelStatusEventMapper? _instance;
  static ModelStatusEventMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ModelStatusEventMapper._());
      SessionEventMapper.ensureInitialized().addSubMapper(_instance!);
      ModelStatusMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ModelStatusEvent';

  static ModelStatus _$status(ModelStatusEvent v) => v.status;
  static const Field<ModelStatusEvent, ModelStatus> _f$status = Field(
    'status',
    _$status,
  );

  @override
  final MappableFields<ModelStatusEvent> fields = const {#status: _f$status};

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'model_status';
  @override
  late final ClassMapperBase superMapper =
      SessionEventMapper.ensureInitialized();

  static ModelStatusEvent _instantiate(DecodingData data) {
    return ModelStatusEvent(status: data.dec(_f$status));
  }

  @override
  final Function instantiate = _instantiate;

  static ModelStatusEvent fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ModelStatusEvent>(map);
  }

  static ModelStatusEvent fromJson(String json) {
    return ensureInitialized().decodeJson<ModelStatusEvent>(json);
  }
}

mixin ModelStatusEventMappable {
  String toJson() {
    return ModelStatusEventMapper.ensureInitialized()
        .encodeJson<ModelStatusEvent>(this as ModelStatusEvent);
  }

  Map<String, dynamic> toMap() {
    return ModelStatusEventMapper.ensureInitialized()
        .encodeMap<ModelStatusEvent>(this as ModelStatusEvent);
  }

  ModelStatusEventCopyWith<ModelStatusEvent, ModelStatusEvent, ModelStatusEvent>
  get copyWith =>
      _ModelStatusEventCopyWithImpl<ModelStatusEvent, ModelStatusEvent>(
        this as ModelStatusEvent,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ModelStatusEventMapper.ensureInitialized().stringifyValue(
      this as ModelStatusEvent,
    );
  }

  @override
  bool operator ==(Object other) {
    return ModelStatusEventMapper.ensureInitialized().equalsValue(
      this as ModelStatusEvent,
      other,
    );
  }

  @override
  int get hashCode {
    return ModelStatusEventMapper.ensureInitialized().hashValue(
      this as ModelStatusEvent,
    );
  }
}

extension ModelStatusEventValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ModelStatusEvent, $Out> {
  ModelStatusEventCopyWith<$R, ModelStatusEvent, $Out>
  get $asModelStatusEvent =>
      $base.as((v, t, t2) => _ModelStatusEventCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ModelStatusEventCopyWith<$R, $In extends ModelStatusEvent, $Out>
    implements SessionEventCopyWith<$R, $In, $Out> {
  ModelStatusCopyWith<$R, ModelStatus, ModelStatus> get status;
  @override
  $R call({ModelStatus? status});
  ModelStatusEventCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ModelStatusEventCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ModelStatusEvent, $Out>
    implements ModelStatusEventCopyWith<$R, ModelStatusEvent, $Out> {
  _ModelStatusEventCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ModelStatusEvent> $mapper =
      ModelStatusEventMapper.ensureInitialized();
  @override
  ModelStatusCopyWith<$R, ModelStatus, ModelStatus> get status =>
      $value.status.copyWith.$chain((v) => call(status: v));
  @override
  $R call({ModelStatus? status}) =>
      $apply(FieldCopyWithData({if (status != null) #status: status}));
  @override
  ModelStatusEvent $make(CopyWithData data) =>
      ModelStatusEvent(status: data.get(#status, or: $value.status));

  @override
  ModelStatusEventCopyWith<$R2, ModelStatusEvent, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ModelStatusEventCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

