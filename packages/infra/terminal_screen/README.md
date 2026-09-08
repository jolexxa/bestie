# terminal_screen

The third package in the
[`agentic_terminal`](../agentic_terminal) stack. Consumes structured
terminal events from [`vt_parser`](../vt_parser/) and maintains a
faithful, observable 2-D cell grid — the in-memory model of "what
a human would see on their terminal right now."

```
process_host → vt_parser → terminal_screen → agentic_terminal
```

Exposes the grid in two flavours:

1. **A live, mutable grid** that renderers (like the eventual
   nocterm host app) can walk at high FPS without allocating.
2. **Immutable snapshots** that agents can take on demand,
   `diff` against a previous snapshot, or feed to a
   `waitFor(predicate)` primitive for scripting interactions.

## Example

```dart
import 'package:process_host/process_host.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:vt_parser/vt_parser.dart';

Future<void> main() async {
  final screen = Screen(rows: 40, cols: 120);
  final parser = VtParser(sink: screen);
  final session = await PtyHost.spawn(
    initialRows: 40,
    initialCols: 120,
  );

  session.output.listen(parser.advance);

  // Wait for the shell prompt, then send a command.
  await screen.waitForText(r'$ ');
  session.writeString('echo hello\n');
  final hit = await screen.waitForText('hello');
  print(hit.text);
}
```

## What's inside

- **Full Unicode handling.** Grapheme clusters (combining marks,
  ZWJ emoji sequences, country-flag regional indicators) and
  East Asian wide characters. No compromises on CJK or emoji.
- **Real-terminal semantics for alt-screen + scrollback.** When
  `vim`/`htop`/`fzf` enters the alt buffer, the main buffer
  (including scrollback) is preserved untouched and restored on
  exit.
- **Soft-wrap reflow on resize.** Lines that wrapped because of
  auto-wrap are un-wrapped and re-wrapped at the new width.
- **Outbound responses.** DA1/DA2/DA3, DSR, cursor position
  reports, palette queries — all answered via an optional
  `Sink<List<int>>` you pass at construction time.
- **Performance-aware data layout.** One mutable `Cell` per
  slot, reused in place; a preallocated ring buffer for
  scrollback (zero-alloc scroll); dirty-row bitmask for
  efficient rendering.

## Status

macOS + Linux. Pure Dart, no FFI in this layer.
