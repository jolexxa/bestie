/// The provider-free remote inference contract for bestie.
library;

export 'src/inference_client.dart' show InferenceClient;
export 'src/models/agent_identity.dart' show AgentIdentity, AgentIdentityKind;
export 'src/models/completion_request.dart' show CompletionRequest;
export 'src/models/inference_dialect.dart' show InferenceDialect;
export 'src/models/inference_endpoint.dart' show InferenceEndpoint;
export 'src/models/inference_event.dart'
    show
        InferenceCompletionFailed,
        InferenceCompletionFinished,
        InferenceEvent,
        InferenceReasoningDelta,
        InferenceTextDelta,
        InferenceToolCallEmitted,
        InferenceToolCallStarted,
        InferenceUsageReported;
export 'src/models/inference_failure.dart'
    show InferenceFailure, InferenceFailureKind;
export 'src/models/inference_message.dart'
    show
        InferenceAssistantMessage,
        InferenceMessage,
        InferenceSystemMessage,
        InferenceToolResultMessage,
        InferenceUserMessage;
export 'src/models/inference_model.dart' show InferenceModel;
export 'src/models/inference_protocol_id.dart' show InferenceProtocolId;
export 'src/models/inference_reasoning.dart'
    show
        InferenceEffort,
        InferenceReasoning,
        InferenceReasoningDefault,
        InferenceReasoningDisabled,
        InferenceReasoningEffort,
        InferenceReasoningEnabled;
export 'src/models/inference_sampling.dart' show InferenceSampling;
export 'src/models/inference_stop_reason.dart' show InferenceStopReason;
export 'src/models/inference_tool.dart' show InferenceTool;
export 'src/models/inference_tool_call.dart' show InferenceToolCall;
export 'src/models/list_models_result.dart'
    show ListModelsResult, ModelsListFailed, ModelsListed;
export 'src/sessions/agent_pool_report.dart'
    show AgentPoolEntry, AgentPoolReport;
export 'src/sessions/agent_session_result.dart'
    show
        AgentSessionFailed,
        AgentSessionInsufficientClaim,
        AgentSessionNoCapacity,
        AgentSessionOpened,
        AgentSessionResult;
export 'src/sessions/agent_sessions.dart' show AgentSessions;
export 'src/sessions/per_agent_window_sessions.dart'
    show PerAgentWindowSessions;
