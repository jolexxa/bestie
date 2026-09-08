// State names mirror the `State` enum in alacritty/vte's
// `src/lib.rs`. Upstream copyright (c) 2016 Joe Wilm; original
// license MIT / Apache-2.0. See ../../THIRD_PARTY_NOTICES.md.

/// The state of the Paul Williams VT500 parser.
///
/// Names and transitions follow the canonical state diagram at
/// <https://vt100.net/emu/dec_ansi_parser>, with the minor
/// modifications described in the `alacritty/vte` source we ported
/// from (UTF-8 support in the ground state and BEL-termination of
/// OSC strings).
enum ParserState {
  /// Default state. Emits printable characters and executes C0/C1
  /// controls. Leaves on ESC (0x1B).
  ground,

  /// ESC has been consumed; waiting for either an intermediate or
  /// the final byte of a 2-byte escape sequence.
  escape,

  /// ESC + one or more intermediate bytes have been consumed.
  escapeIntermediate,

  /// Entered after `ESC [`. Waiting for parameters, intermediates,
  /// or a final byte.
  csiEntry,

  /// Currently collecting CSI parameters (digits, `;`, `:`).
  csiParam,

  /// Currently collecting CSI intermediate bytes (0x20..0x2F).
  csiIntermediate,

  /// Draining a malformed CSI sequence; bytes are discarded until
  /// the final byte arrives.
  csiIgnore,

  /// Entered after `ESC P`. Waiting for parameters, intermediates,
  /// or a final byte.
  dcsEntry,

  /// Currently collecting DCS parameters.
  dcsParam,

  /// Currently collecting DCS intermediate bytes.
  dcsIntermediate,

  /// Streaming DCS payload bytes via `put` between `hook` and
  /// `unhook`.
  dcsPassthrough,

  /// Draining a malformed DCS sequence.
  dcsIgnore,

  /// Entered after `ESC ]`. Collecting OSC payload bytes until BEL
  /// or ST terminates.
  oscString,

  /// Entered after `ESC X`, `ESC ^`, or `ESC _` (SOS, PM, APC).
  /// Payload is silently discarded.
  sosPmApcString,
}
