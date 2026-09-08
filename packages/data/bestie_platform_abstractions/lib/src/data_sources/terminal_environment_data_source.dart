import 'dart:io';

import 'package:intentions/intentions.dart';

/// Mutates process-level terminal environment (fd redirects, termios flags)
/// at startup, with a uniform handle for restoring each override later.
///
/// nocterm owns its own raw-mode lifecycle (`stdin.lineMode`, `echoMode`).
/// This data source covers the things nocterm doesn't — fd redirects (so
/// native stderr spam doesn't leak into the TUI) and surgical termios bits
/// the kernel swallows before Dart sees them (e.g., IEXTEN's VDISCARD on ^O).
@dataSource
abstract interface class TerminalEnvironmentDataSource {
  /// Redirects fd 2 to [targetPath]. The returned handle's
  /// [TerminalOverride.originalSink] writes to the saved original stderr
  /// fd so callers (boring mode) can still reach the real terminal.
  /// Returns null on platforms that don't support the redirect.
  TerminalOverride? redirectStderr({required String targetPath});

  /// Stops the OS from intercepting the given key [groups] on stdin, so
  /// they arrive as raw bytes instead. Returns null when stdin is not a
  /// TTY (`stdin.hasTerminal == false`), or when nothing on this
  /// platform intercepts the requested groups.
  TerminalOverride? captureInput(Set<InputCapture> groups);

  /// Pushes the current terminal window/icon title onto the terminal's title
  /// stack (xterm CSI 22;0t) and sets a new title to [title] via OSC 0. The
  /// returned override's revert pops the stack (CSI 23;0t) to restore
  /// whatever the terminal had before. Returns null when stdout is not a TTY.
  TerminalOverride? setWindowTitle(String title);
}

/// Handle returned by a [TerminalEnvironmentDataSource] override. Holds
/// enough captured state to undo the override on [revert].
@model
@PartOf(TerminalEnvironmentDataSource)
abstract class TerminalOverride {
  const TerminalOverride();

  /// Side-channel to the pre-override target. Only fd redirects populate
  /// this; for termios overrides it stays null.
  IOSink? get originalSink => null;

  /// Restores the pre-override state. After this returns, [originalSink]
  /// (if any) is invalid — its underlying fd has been closed.
  Future<void> revert();
}

/// Groups of keystrokes the OS would otherwise intercept before the app
/// sees them.
///
/// Named for what bestie wants rather than for how a platform spells it —
/// the POSIX mapping is termios flag bits, the Windows mapping is console
/// mode bits, and one group has no Windows meaning at all. Stating the
/// intent lets an implementation answer "nothing to do here" honestly
/// instead of the interface implying a termios call.
@model
enum InputCapture {
  /// ^C, ^\ and ^Z as raw bytes rather than SIGINT / SIGQUIT / SIGTSTP.
  /// The embedded shell needs ^C as a byte; otherwise nocterm's SIGINT
  /// handler tears bestie down before the page's `InputListener` sees it.
  ///
  /// POSIX: clear `ISIG`. Windows: clear `ENABLE_PROCESSED_INPUT`.
  controlKeys,

  /// ^O, ^V and ^R as raw bytes rather than being consumed by the line
  /// driver as VDISCARD / VLNEXT / VREPRINT.
  ///
  /// POSIX: clear `IEXTEN`. Windows: no equivalent — nothing intercepts
  /// these, so implementations report no override.
  editingKeys,

  /// ^S and ^Q as raw bytes rather than software flow control.
  ///
  /// POSIX: clear `IXON`. Windows: covered by the same console-mode bit
  /// as [controlKeys].
  flowControl,
}
