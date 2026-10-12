/// The provider-free chat completion contract for bestie.
library;

export 'src/completion_client.dart' show CompletionClient;
export 'src/models/agent_identity.dart' show AgentIdentity, AgentIdentityKind;
export 'src/models/completion_event.dart'
    show
        CompletionEvent,
        CompletionFailed,
        CompletionFinished,
        CompletionPrefillProgressed,
        CompletionReasoningDelta,
        CompletionTextDelta,
        CompletionToolCallEmitted,
        CompletionToolCallStarted,
        CompletionUsageReported;
export 'src/models/completion_failure.dart'
    show CompletionFailure, CompletionFailureKind;
export 'src/models/completion_message.dart'
    show
        CompletionAssistantMessage,
        CompletionMessage,
        CompletionSystemMessage,
        CompletionToolResultMessage,
        CompletionUserMessage;
export 'src/models/completion_reasoning.dart'
    show
        CompletionEffort,
        CompletionReasoning,
        CompletionReasoningDefault,
        CompletionReasoningDisabled,
        CompletionReasoningEffort,
        CompletionReasoningEnabled;
export 'src/models/completion_request.dart' show CompletionRequest;
export 'src/models/completion_sampling.dart' show CompletionSampling;
export 'src/models/completion_stop_reason.dart' show CompletionStopReason;
export 'src/models/completion_tool.dart' show CompletionTool;
export 'src/models/completion_tool_call.dart' show CompletionToolCall;
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
