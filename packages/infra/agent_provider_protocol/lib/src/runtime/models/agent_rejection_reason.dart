/// Why a command was refused before it could run.
///
/// Shared across every per-operation `*Rejected` result — the operation is
/// carried by the result type, this only names the cause.
enum AgentRuntimeRejectionReason {
  busy,
  disposed,
  invalidConfig,
  invalidRuntimeOptions,
  primaryAgentRequired,
  primaryAgentAlreadyCreated,
  primaryCompactionPending,
  insufficientClaimSpace,
  insufficientContextSpace,
  noSequenceCapacity,
  agentCapacityReached,
  unknownAgent,
  agentNotRunning,
  userMessageTooLarge,
  initialContextTooLarge,
  schedulerFailure,
  nothingToCompact,
  unsupported,
}
