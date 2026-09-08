# Third-party notices — `vt_parser`

`vt_parser` is a pure-Dart port of the state machine from
[`alacritty/vte`](https://github.com/alacritty/vte), redistributed
under the terms of vte's MIT license (vte is dual-licensed under
MIT or Apache-2.0; we chose the MIT option).

## Portions ported from `alacritty/vte`

The following files in `lib/src/` are Dart translations of logic from
`alacritty/vte`:

- **`parser.dart`** — the state-machine dispatch, `_advance_*`
  functions, `_action_*` actions, and UTF-8 handling are direct
  ports of `src/lib.rs`.
- **`params.dart`** — the fixed-capacity parameter list with
  subparameter (`:`-separated) support is a direct port of
  `src/params.rs`.
- **`state.dart`** — the 13-state enum (Ground, Escape,
  EscapeIntermediate, CsiEntry, CsiParam, CsiIntermediate,
  CsiIgnore, DcsEntry, DcsParam, DcsIntermediate, DcsPassthrough,
  DcsIgnore, OscString, SosPmApcString) mirrors vte's `State` enum.

The structure, transition rules, action semantics, and max-param /
max-intermediate / max-OSC-raw limits all match vte. The public
event types (`ParserEvent`, `ParserSink`) and the `events` stream
are our own design layered on top of vte's `Perform` trait concept.

## vte MIT License (verbatim from `external/vte/LICENSE-MIT`)

```
Copyright (c) 2016 Joe Wilm

Permission is hereby granted, free of charge, to any
person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the
Software without restriction, including without
limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice
shall be included in all copies or substantial portions
of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```
