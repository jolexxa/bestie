/// User-facing copy for the chat feature.
///
/// Single home for every string the chat surface shows the user. If you're
/// hunting for a piece of text shown in chat, this is the only place to look —
/// `ChatLogic` and friends pull every phrase from here so wording changes
/// land in exactly one diff.
abstract final class ChatStrings {
  /// System message shown when no hosted provider is configured yet.
  static const String providerUnconfigured =
      'No provider configured. Add an OpenRouter or Fireworks AI API key, '
      'or a custom endpoint URL, in config (Ctrl+O) to start chatting.';

  /// System message shown after a saved conversation replaces the current
  /// one.
  static const String conversationLoaded = 'Conversation loaded.';

  /// System message shown when a loaded conversation began somewhere other
  /// than where the app is running now.
  static String workingDirectoryChanged(String from, String to) =>
      'This conversation started in $from; tools now run in $to.';

  /// Marker subtitle shown above the rolled-up compacted prefix. [before]
  /// is the real summed token cost of the compacted messages.
  static String compactionResult(int before) => 'Compacted ~$before tokens';

  /// Marker subtitle while a compaction pass is still folding.
  static String compactionInProgress(int before) =>
      'Compacting ~$before tokens…';
}
