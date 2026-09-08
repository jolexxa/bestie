/// Maximum number of parameters (including subparameters) a single
/// CSI or DCS sequence may contain before the parser switches to its
/// `Ignore` state and drains the rest of the sequence.
///
/// Matches alacritty/vte so we inherit their battle-tested limits.
const int maxParams = 32;

/// Maximum number of intermediate bytes in an escape/CSI/DCS sequence.
/// vte uses the same value. Sequences exceeding this are marked
/// `ignore` on dispatch.
const int maxIntermediates = 2;

/// Maximum number of `;`-separated OSC parameters.
const int maxOscParams = 16;

/// Maximum number of raw bytes an OSC payload may contain. vte uses
/// the same default (`MAX_OSC_RAW = 1024`).
const int maxOscRaw = 1024;
