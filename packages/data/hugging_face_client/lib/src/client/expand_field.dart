/// Fields the Hub includes in model responses when asked via `expand[]`.
enum ModelExpandField {
  /// The model author.
  author('author'),

  /// Creation timestamp.
  createdAt('createdAt'),

  /// Whether the model is disabled.
  disabled('disabled'),

  /// Recent download count.
  downloads('downloads'),

  /// All-time download count.
  downloadsAllTime('downloadsAllTime'),

  /// Gated access mode.
  gated('gated'),

  /// What the Hub read from the repo's GGUF files: architecture, context
  /// length, parameter count and chat template. Model lookups include it
  /// unasked; searches only when asked.
  gguf('gguf'),

  /// Last modified timestamp.
  lastModified('lastModified'),

  /// The library that produced this model (e.g. `"transformers"`).
  libraryName('library_name'),

  /// Like count.
  likes('likes'),

  /// Pipeline tag (e.g. `"text-generation"`).
  pipelineTag('pipeline_tag'),

  /// Whether the model is private.
  private_('private'),

  /// Latest commit SHA.
  sha('sha'),

  /// File listing (siblings).
  siblings('siblings'),

  /// Tags.
  tags('tags'),

  /// Trending score.
  trendingScore('trendingScore'),

  /// Total storage used by the repo.
  usedStorage('usedStorage');

  const ModelExpandField(this.value);

  /// The query parameter value sent to the API.
  final String value;
}
