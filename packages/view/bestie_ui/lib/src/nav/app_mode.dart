/// The primary mode of the bestie app.
enum AppMode {
  /// Chat with the AI.
  chat;

  /// Human-readable label for this mode.
  String get label => switch (this) {
    AppMode.chat => 'Chat',
  };

  static List<AppMode> modes = [AppMode.chat];

  /// Returns the next mode in the cycle.
  AppMode get next => modes[(index + 1) % modes.length];

  /// Returns the previous mode in the cycle.
  AppMode get previous => modes[(index - 1) % modes.length];
}
