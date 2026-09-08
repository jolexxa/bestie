import 'package:process_host/process_host.dart';

/// Tracks the host terminal's window size by polling.
///
/// Windows has no `SIGWINCH`, so there is no event to subscribe to — the size
/// is sampled on an interval and a change is emitted only when it differs from
/// the last sample. nocterm's stdio backend polls for resize the same way.
class WindowsHostWinsizeSource implements HostWinsizeSource {
  const WindowsHostWinsizeSource({
    this.reader = defaultWinsizeReader,
    this.pollInterval = const Duration(milliseconds: 50),
    this.fallbackRows = 24,
    this.fallbackCols = 80,
  });

  /// Reads the host terminal's current dimensions. Injectable for tests.
  final WinsizeReader reader;

  /// How often [changes] samples the terminal size.
  final Duration pollInterval;

  /// Size reported when no terminal is attached.
  final int fallbackRows;
  final int fallbackCols;

  @override
  Winsize get current => currentHostWinsize(
    reader: reader,
    fallbackRows: fallbackRows,
    fallbackCols: fallbackCols,
  );

  @override
  Stream<Winsize> get changes {
    Winsize? last;
    return Stream<void>.periodic(pollInterval)
        .map((_) => reader())
        .where((size) => size != null)
        .cast<Winsize>()
        .where((size) {
          if (size == last) return false;
          last = size;
          return true;
        });
  }
}
