/// The wire protocols an inference client can speak.
enum InferenceProtocolId {
  /// `POST /chat/completions` with server-sent-event streaming.
  openAiCompat,
}
