/// Why an in-flight run failed, carried by the `AgentFailed` event.
enum AgentRunFailureReason {
  primaryCreationFailed,
  subagentCreationFailed,
  subagentReleaseFailed,
  contextBuildFailed,
  loopFailed,
  compactionFailed,
  primaryConfigUpdateFailed,
  schedulerDeferred,
}
