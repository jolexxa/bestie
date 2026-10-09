/// The wire contract between bestie and its local inference server.
library;

export 'package:llm_model_profiles/llm_model_profiles.dart' show ModelProfileId;

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
        bestieSessionPath;
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
export 'src/models/inference_lock_file.dart'
    show InferenceLockFile, InferenceLockFileMapper;
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
export 'src/models/session_event.dart'
    show
        ModelStatusEvent,
        PoolAgent,
        PoolSnapshotEvent,
        SessionEvent,
        SessionEventMapper,
        SessionOpened;
