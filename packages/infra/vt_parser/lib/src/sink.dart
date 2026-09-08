/// A low-overhead callback interface for consumers that don't want
/// to pay for `ParserEvent` allocation on every dispatch.
///
/// Methods receive the parser's internal buffers directly; the lists
/// they're given are only valid for the duration of the call and MUST
/// NOT be retained. If you need to keep them, copy first.
///
/// The `events` stream on the parser always fires alongside the sink
/// if both are in use. Either one is fine on its own.
abstract class ParserSink {
  /// Called for each printable code point emitted in ground state.
  void onPrint(int char);

  /// Called for each C0 (0x00..0x1F) or C1 (0x80..0x9F) control byte.
  void onExecute(int byte);

  /// Called when a simple `ESC <final>` sequence is dispatched.
  void onEscDispatch({
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  });

  /// Called when a CSI sequence finishes.
  void onCsiDispatch({
    required List<List<int>> params,
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  });

  /// Called when an OSC sequence finishes.
  void onOscDispatch({
    required List<List<int>> params,
    required bool bellTerminated,
  });

  /// Called when a DCS payload is about to begin. Subsequent bytes
  /// arrive via [onDcsPut] until [onDcsUnhook] fires.
  void onDcsHook({
    required List<List<int>> params,
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  });

  /// Called for each byte of a DCS payload.
  void onDcsPut(int byte);

  /// Called when a DCS payload ends.
  void onDcsUnhook();
}
