# agentic_terminal

The top-level composition package for the agentic terminal stack.
Wires `process_host` + `vt_parser` + `terminal_screen` into a single
`AgentTerminal.spawn(...)` handle so agents can drive interactive
TUI programs with minimal boilerplate.

```dart
import 'package:agentic_terminal/agentic_terminal.dart';

Future<void> main() async {
  final term = await AgentTerminal.spawn(
    spawnerBinaryPath: '/path/to/spawner',
  );

  await term.waitForText(r'$ ');
  term.writeString('echo hello\n');

  final snap = await term.waitForText('hello');
  print(snap.text);

  await term.close();
}
```

`spawner` is the native PTY helper — build it with
`dart run melos run build:spawner` from the repo root.

## Spawning without naming a platform

Callers that shouldn't know how terminals get created hold a
`TerminalHost` instead:

```dart
final TerminalHost host = PosixTerminalHost(
  spawnerBinaryPath: '/path/to/spawner',
);
final term = await host.spawn(launchMode: ShellLaunchMode.interactive);
```

POSIX drives a helper binary over a pty; Windows drives ConPTY in-process,
and carries the path of the `conpty.dll` bestie ships instead.

## What it does

- Spawns a child process on a real pseudo-terminal via `process_host`
  (login shell by default, fully-cloned environment).
- Pipes raw PTY bytes through a VT500 parser (`vt_parser`) into
  a live cell grid (`terminal_screen`).
- Wires outbound responses (DA, DSR, palette queries) back to the
  child's stdin so programs that probe terminal capabilities
  get real answers.
- Exposes `screen`, `snapshot()`, `waitForText()`, `waitForRegex()`,
  `waitFor()`, `writeString()`, `writeBytes()`, `sendKey()`,
  `resize()`, `kill()`, and `close()`.

## Status

macOS + Linux. Windows not yet supported.
