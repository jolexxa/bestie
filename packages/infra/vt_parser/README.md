# vt_parser

A pure-Dart [Paul Williams VT500 state-machine
parser](https://vt100.net/emu/dec_ansi_parser) for ANSI/VT escape
sequences. It's the second layer of the
[`agentic_terminal`](../agentic_terminal) stack — downstream of `process_host`
(which produces raw PTY bytes) and upstream of `terminal_screen`
(which mutates a cell grid in response to parser events).

`vt_parser` has exactly one job: turn a stream of bytes into a stream
of structured terminal events. It does no interpretation of those
events — SGR codes, mode changes, mouse reports, and everything else
are handed off to consumers as-is. That keeps the parser honest and
the downstream packages cleanly decoupled.

## Why port vte instead of using xterm.dart?

We considered three approaches when picking an implementation:

1. Depend on [`xterm.dart`](https://pub.dev/packages/xterm)'s parser.
2. Port [`alacritty/vte`](https://github.com/alacritty/vte) from Rust
   to Dart.
3. Write fresh from the Paul Williams spec.

We chose (2). `xterm.dart`'s parser is a clever lookup-table fast
path, but it's tightly coupled to xterm.dart's own screen model (42
concrete handler methods that interpret SGR codes, set colors, etc.),
and it doesn't support:

- `:` subparameters (breaks ITU-T T.416 extended colors like
  `CSI 38:2:255:0:0m`).
- DCS (Device Control String) lifecycle — commented out.
- Byte-level UTF-8 with explicit partial-sequence handling across
  chunk boundaries.

`alacritty/vte` is the canonical strict Paul Williams implementation,
used by alacritty itself. It has a minimal 7-method `Perform` trait
that stays cleanly out of the interpretation business, full subparam
support, byte-exact streaming, and an embedded test suite we ported
alongside the code. Rust → Dart translation is mechanical for a state
machine of this size: enums map directly, `match` becomes `switch`,
fixed arrays become `List<int>`.

## Example

```dart
import 'package:vt_parser/vt_parser.dart';

void main() {
  final parser = VtParser();
  parser.events.listen((event) {
    switch (event) {
      case PrintEvent(:final char):
        stdout.write(String.fromCharCode(char));
      case ExecuteEvent(:final byte):
        print('execute 0x${byte.toRadixString(16)}');
      case CsiDispatchEvent(:final params, :final finalByte):
        print('CSI $params ${String.fromCharCode(finalByte)}');
      case OscDispatchEvent(:final params):
        print('OSC ${params.length} param(s)');
      case EscDispatchEvent():
      case DcsHookEvent():
      case DcsPutEvent():
      case DcsUnhookEvent():
        // ...
    }
  });

  parser.advance('\x1B[31mhello\x1B[0m'.codeUnits);
}
```

## Status

Pure Dart; works on every platform Dart supports. Fixture-based
golden tests cover real-shell byte streams for `ls --color`, `vim`,
`htop`, and `fzf`.

## License and attribution

`vt_parser` is dual-licensed under either:

- **Apache License, Version 2.0** — see [`LICENSE-APACHE`](LICENSE-APACHE)
- **MIT License** — see [`LICENSE-MIT`](LICENSE-MIT)

at the recipient's option. This mirrors the dual licensing of
[`alacritty/vte`](https://github.com/alacritty/vte), from which
`vt_parser`'s state machine, parameter list, and state enum are
ported. `vt_parser` keeps the upstream's permissive dual-license
to stay spirit-aligned with the work it derives from.

Joe Wilm's original copyright on the ported portions is preserved
in file-level headers and in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md), which contains
the full upstream license text.
