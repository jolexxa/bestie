/// The wire contract between bestie and its local inference server.
library;

export 'package:model_profiles/model_profiles.dart' show ModelProfileId;

export 'src/bestie_routes.dart'
    show
        bestieAgentHeader,
        bestieAgentPath,
        bestieChatTemplateKwargsField,
        bestieEnableThinkingKey,
        bestieHealthPath,
        bestieModelPath,
        bestieOwnerHeader,
        bestieOwnerPidHeader,
        bestieProtocolVersion,
        bestieReturnProgressField,
        bestieSessionPath,
        bestieTimingsPerTokenField;
export 'src/bestie_server.dart' show bestieServerBusyMessage, bestieServerName;
export 'src/models/agent_lease.dart'
    show
        AgentInsufficientClaim,
        AgentLeaseKind,
        AgentNoCapacity,
        AgentOpenRequest,
        AgentOpenRequestMapper,
        AgentOpenResult,
        AgentOpenResultMapper,
        AgentOpened;
export 'src/models/bestie_model_list.dart'
    show BestieModel, BestieModelFacts, BestieModelList, BestieModelListMapper;
export 'src/models/health_response.dart'
    show HealthResponse, HealthResponseMapper;
export 'src/models/model_index.dart'
    show
        ModelDownloaded,
        ModelIndex,
        ModelIndexDecodeResult,
        ModelIndexDecoded,
        ModelIndexEntry,
        ModelIndexEntryMapper,
        ModelIndexMapper,
        ModelIndexUndecodable,
        ModelProvenance,
        ModelSamplingDefaults,
        ModelScanned;
export 'src/models/model_reasoning.dart'
    show
        ModelReasoning,
        ModelReasoningAlways,
        ModelReasoningEfforts,
        ModelReasoningNone,
        ModelReasoningToggle;
export 'src/models/model_status.dart'
    show
        ModelFailed,
        ModelFitting,
        ModelLoadRequest,
        ModelLoadRequestMapper,
        ModelLoading,
        ModelReady,
        ModelStatus,
        ModelStatusMapper,
        ModelUnloaded;
export 'src/models/server_error.dart'
    show ServerBusy, ServerError, ServerErrorMapper;
export 'src/models/server_lock_file.dart'
    show ServerLockFile, ServerLockFileMapper;
export 'src/models/session_event.dart'
    show
        ModelStatusEvent,
        PoolAgent,
        PoolSnapshotEvent,
        SessionEvent,
        SessionEventMapper,
        SessionOpened;
