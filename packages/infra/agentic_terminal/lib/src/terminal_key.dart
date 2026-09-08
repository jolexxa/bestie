/// Named terminal keys for `AgentTerminal.sendKey`.
///
/// Each key maps to the byte sequence a real terminal would send
/// when that key is pressed. Arrow keys use the "normal mode"
/// encoding (`CSI A` etc.); if the child has enabled application
/// cursor keys (DECCKM), the caller should check
/// `screen.modes.cursorKeysApp` and switch to `SS3` encoding
/// manually via `writeString` — this enum intentionally covers
/// only the common defaults.
enum TerminalKey {
  /// Carriage return (`\r`).
  enter('\r'),

  /// Horizontal tab (`\t`).
  tab('\t'),

  /// Escape (`\x1B`).
  escape('\x1B'),

  /// Ctrl-C — sends SIGINT to the child's foreground process
  /// group via the PTY's line discipline.
  ctrlC('\x03'),

  /// Ctrl-D — EOF on stdin.
  ctrlD('\x04'),

  /// Ctrl-Z — sends SIGTSTP.
  ctrlZ('\x1A'),

  /// Ctrl-L — conventional "clear screen" request.
  ctrlL('\x0C'),

  /// Backspace / DEL (`\x7F`).
  backspace('\x7F'),

  /// Up arrow (normal mode).
  up('\x1B[A'),

  /// Down arrow (normal mode).
  down('\x1B[B'),

  /// Right arrow (normal mode).
  right('\x1B[C'),

  /// Left arrow (normal mode).
  left('\x1B[D');

  const TerminalKey(this.sequence);

  /// The byte sequence to write to the PTY.
  final String sequence;
}
