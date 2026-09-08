/// Mints lexically sortable, strictly increasing call or agent identifiers.
final class CallIdMinter {
  CallIdMinter({DateTime Function()? now, String? previous})
    : _now = now ?? DateTime.now,
      _previous = previous;

  static final DateTime _epoch = DateTime.utc(2026);
  final DateTime Function() _now;
  String? _previous;

  /// Advances past [id] when resuming an existing transcript.
  void seed(String id) {
    final previous = _previous;
    if (previous == null || id.compareTo(previous) > 0) _previous = id;
  }

  /// Advances past every recovered id when resuming a transcript.
  void seedAll(Iterable<String> ids) => ids.forEach(seed);

  String mint() {
    final seconds = _now().toUtc().difference(_epoch).inSeconds;
    final candidate = seconds < 0
        ? '000000'
        : seconds.toRadixString(36).padLeft(6, '0');
    final previous = _previous;
    if (previous == null || candidate.compareTo(previous) > 0) {
      return _previous = candidate;
    }
    final next = (int.parse(previous, radix: 36) + 1)
        .toRadixString(36)
        .padLeft(6, '0');
    return _previous = next;
  }
}
