import 'dart:io';

/// A (rows, cols) window size.
typedef Winsize = ({int rows, int cols});

/// Function shape used to read the host terminal dimensions. Injectable for
/// tests.
typedef WinsizeReader = Winsize? Function();

/// Reads the host terminal's current window size via [stdout].
///
/// Returns `null` if [stdout] is not attached to a terminal (e.g. the
/// process is being piped).
Winsize? defaultWinsizeReader() => winsizeOf(stdout);

/// Reads [out]'s window size, or `null` when it is not a terminal.
Winsize? winsizeOf(Stdout out) {
  if (!out.hasTerminal) return null;
  return (rows: out.terminalLines, cols: out.terminalColumns);
}

/// Returns the current host terminal size, falling back to
/// ([fallbackRows], [fallbackCols]) when no terminal is attached.
///
/// [reader] is injectable so that tests can simulate various host states.
Winsize currentHostWinsize({
  int fallbackRows = 24,
  int fallbackCols = 80,
  WinsizeReader reader = defaultWinsizeReader,
}) {
  final value = reader();
  if (value == null) return (rows: fallbackRows, cols: fallbackCols);
  return value;
}
