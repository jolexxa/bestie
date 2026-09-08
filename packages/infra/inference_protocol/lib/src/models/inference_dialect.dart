/// Which vendor extensions an OpenAI-compatible server understands beyond
/// the base chat-completions API.
enum InferenceDialect {
  /// Plain OpenAI: reasoning is controlled through `reasoning_effort`.
  openAi,

  /// OpenRouter: reasoning is controlled through the `reasoning` object.
  openRouter,
}
