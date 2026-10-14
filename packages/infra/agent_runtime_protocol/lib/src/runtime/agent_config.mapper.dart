// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'agent_config.dart';

class AgentConfigMapper extends ClassMapperBase<AgentConfig> {
  AgentConfigMapper._();

  static AgentConfigMapper? _instance;
  static AgentConfigMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AgentConfigMapper._());
      SamplingOptionsMapper.ensureInitialized();
      ToolDefinitionMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'AgentConfig';

  static String _$systemPrompt(AgentConfig v) => v.systemPrompt;
  static const Field<AgentConfig, String> _f$systemPrompt = Field(
    'systemPrompt',
    _$systemPrompt,
  );
  static SamplingOptions _$sampling(AgentConfig v) => v.sampling;
  static const Field<AgentConfig, SamplingOptions> _f$sampling = Field(
    'sampling',
    _$sampling,
  );
  static String _$reasoningMode(AgentConfig v) => v.reasoningMode;
  static const Field<AgentConfig, String> _f$reasoningMode = Field(
    'reasoningMode',
    _$reasoningMode,
  );
  static String _$compactionReasoningMode(AgentConfig v) =>
      v.compactionReasoningMode;
  static const Field<AgentConfig, String> _f$compactionReasoningMode = Field(
    'compactionReasoningMode',
    _$compactionReasoningMode,
  );
  static double _$compactionRatio(AgentConfig v) => v.compactionRatio;
  static const Field<AgentConfig, double> _f$compactionRatio = Field(
    'compactionRatio',
    _$compactionRatio,
  );
  static List<ToolDefinition> _$tools(AgentConfig v) => v.tools;
  static const Field<AgentConfig, List<ToolDefinition>> _f$tools = Field(
    'tools',
    _$tools,
  );

  @override
  final MappableFields<AgentConfig> fields = const {
    #systemPrompt: _f$systemPrompt,
    #sampling: _f$sampling,
    #reasoningMode: _f$reasoningMode,
    #compactionReasoningMode: _f$compactionReasoningMode,
    #compactionRatio: _f$compactionRatio,
    #tools: _f$tools,
  };

  static AgentConfig _instantiate(DecodingData data) {
    return AgentConfig(
      systemPrompt: data.dec(_f$systemPrompt),
      sampling: data.dec(_f$sampling),
      reasoningMode: data.dec(_f$reasoningMode),
      compactionReasoningMode: data.dec(_f$compactionReasoningMode),
      compactionRatio: data.dec(_f$compactionRatio),
      tools: data.dec(_f$tools),
    );
  }

  @override
  final Function instantiate = _instantiate;
}

mixin AgentConfigMappable {
  AgentConfigCopyWith<AgentConfig, AgentConfig, AgentConfig> get copyWith =>
      _AgentConfigCopyWithImpl<AgentConfig, AgentConfig>(
        this as AgentConfig,
        $identity,
        $identity,
      );
}

extension AgentConfigValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AgentConfig, $Out> {
  AgentConfigCopyWith<$R, AgentConfig, $Out> get $asAgentConfig =>
      $base.as((v, t, t2) => _AgentConfigCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AgentConfigCopyWith<$R, $In extends AgentConfig, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  SamplingOptionsCopyWith<$R, SamplingOptions, SamplingOptions> get sampling;
  ListCopyWith<
    $R,
    ToolDefinition,
    ToolDefinitionCopyWith<$R, ToolDefinition, ToolDefinition>
  >
  get tools;
  $R call({
    String? systemPrompt,
    SamplingOptions? sampling,
    String? reasoningMode,
    String? compactionReasoningMode,
    double? compactionRatio,
    List<ToolDefinition>? tools,
  });
  AgentConfigCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AgentConfigCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AgentConfig, $Out>
    implements AgentConfigCopyWith<$R, AgentConfig, $Out> {
  _AgentConfigCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AgentConfig> $mapper =
      AgentConfigMapper.ensureInitialized();
  @override
  SamplingOptionsCopyWith<$R, SamplingOptions, SamplingOptions> get sampling =>
      $value.sampling.copyWith.$chain((v) => call(sampling: v));
  @override
  ListCopyWith<
    $R,
    ToolDefinition,
    ToolDefinitionCopyWith<$R, ToolDefinition, ToolDefinition>
  >
  get tools => ListCopyWith(
    $value.tools,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(tools: v),
  );
  @override
  $R call({
    String? systemPrompt,
    SamplingOptions? sampling,
    String? reasoningMode,
    String? compactionReasoningMode,
    double? compactionRatio,
    List<ToolDefinition>? tools,
  }) => $apply(
    FieldCopyWithData({
      if (systemPrompt != null) #systemPrompt: systemPrompt,
      if (sampling != null) #sampling: sampling,
      if (reasoningMode != null) #reasoningMode: reasoningMode,
      if (compactionReasoningMode != null)
        #compactionReasoningMode: compactionReasoningMode,
      if (compactionRatio != null) #compactionRatio: compactionRatio,
      if (tools != null) #tools: tools,
    }),
  );
  @override
  AgentConfig $make(CopyWithData data) => AgentConfig(
    systemPrompt: data.get(#systemPrompt, or: $value.systemPrompt),
    sampling: data.get(#sampling, or: $value.sampling),
    reasoningMode: data.get(#reasoningMode, or: $value.reasoningMode),
    compactionReasoningMode: data.get(
      #compactionReasoningMode,
      or: $value.compactionReasoningMode,
    ),
    compactionRatio: data.get(#compactionRatio, or: $value.compactionRatio),
    tools: data.get(#tools, or: $value.tools),
  );

  @override
  AgentConfigCopyWith<$R2, AgentConfig, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AgentConfigCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

