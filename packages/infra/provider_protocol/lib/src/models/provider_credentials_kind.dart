/// What a provider asks the user for before it can be used.
enum ProviderCredentialsKind {
  /// Nothing.
  none,

  /// A key, at an address the provider knows.
  apiKey,

  /// An address of the user's own, and optionally a key.
  endpoint,
}
