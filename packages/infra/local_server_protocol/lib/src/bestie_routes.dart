/// The protocol version both sides compare during the health handshake.
const bestieProtocolVersion = 1;

/// Names the agent a chat completion belongs to, so the server reuses that
/// agent's cached prefix.
const bestieAgentHeader = 'X-Bestie-Agent';

/// Carries the owner token from the session's opening event. Lease and model
/// requests without it are refused.
const bestieOwnerHeader = 'X-Bestie-Owner';

/// Carries the opening client's process id on a session request, so a client
/// refused as busy learns who holds the session.
const bestieOwnerPidHeader = 'X-Bestie-Pid';

/// The chat-completion field holding chat-template switches, as llama.cpp's
/// server names it.
const bestieChatTemplateKwargsField = 'chat_template_kwargs';

/// The chat-template switch that turns thinking on or off for models that
/// can toggle it. `reasoning_effort` takes precedence when both are sent.
const bestieEnableThinkingKey = 'enable_thinking';

/// The chat-completion switch that streams how far the prompt has been read
/// as `prompt_progress` chunks, as llama.cpp's server names it.
const bestieReturnProgressField = 'return_progress';

/// The chat-completion switch that puts a `timings` object on every streamed
/// chunk, whose `predicted_n` counts the tokens generated so far, as
/// llama.cpp's server names it.
const bestieTimingsPerTokenField = 'timings_per_token';

/// `GET`: the handshake, answered with a health response.
const bestieHealthPath = '/bestie/v1/health';

/// `GET`: the owner session, streamed as server-sent session events.
const bestieSessionPath = '/bestie/v1/session';

/// `POST` opens a lease for the agent, `DELETE` closes it.
String bestieAgentPath(String agentId) =>
    '/bestie/v1/agents/${Uri.encodeComponent(agentId)}';

/// `POST` loads a model, `DELETE` unloads it, `GET` reports its status.
const bestieModelPath = '/bestie/v1/model';
