import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A 3-row-high lowercase font built from a 3×6 pixel grid, where each cell
/// packs two vertical half-pixels.
@model
class BlockFont extends AsciiFont {
  /// Creates a [BlockFont].
  const BlockFont();

  @override
  int get height => 3;

  @override
  int get letterSpacing => 1;

  @override
  Map<String, AsciiGlyph> get glyphs => const {
    'A': AsciiGlyph(['   ', '▄▀█', '▀▄█']),
    'B': AsciiGlyph(['█  ', '█▀▄', '█▄▀']),
    'C': AsciiGlyph(['   ', '▄▀▀', '▀▄▄']),
    'D': AsciiGlyph(['  █', '▄▀█', '▀▄█']),
    'E': AsciiGlyph(['   ', '▄▀▄', '▀▄▄']),
    'F': AsciiGlyph(['▄▀', '█▄', '█ ']),
    'G': AsciiGlyph(['   ', '▄▀█', '▄▄▀']),
    'H': AsciiGlyph(['█  ', '█▀▄', '█ █']),
    'I': AsciiGlyph(['▀', '█', '█']),
    'J': AsciiGlyph([' ▀', ' █', '▄▀']),
    'K': AsciiGlyph(['█  ', '█▄▀', '█ █']),
    'L': AsciiGlyph(['█ ', '█ ', '▀▄']),
    'M': AsciiGlyph(['   ', '█▄█', '█ █']),
    'N': AsciiGlyph(['   ', '█▀▄', '█ █']),
    'O': AsciiGlyph(['   ', '▄▀▄', '▀▄▀']),
    'P': AsciiGlyph(['   ', '█▀▄', '█▀ ']),
    'Q': AsciiGlyph(['   ', '▄▀█', ' ▀█']),
    'R': AsciiGlyph(['   ', '█▀▄', '█  ']),
    'S': AsciiGlyph(['   ', '▄▀▀', '▄▄▀']),
    'T': AsciiGlyph([' ▄ ', '▀█▀', ' ▀▄']),
    'U': AsciiGlyph(['   ', '█ █', '▀▄█']),
    'V': AsciiGlyph(['   ', '█ █', ' █ ']),
    'W': AsciiGlyph(['   ', '█ █', '█▀█']),
    'X': AsciiGlyph(['   ', '▀▄▀', '▄▀▄']),
    'Y': AsciiGlyph(['   ', '█ █', '▀▀█']),
    'Z': AsciiGlyph(['   ', '▀▀█', '█▄▄']),
    ' ': AsciiGlyph(['  ', '  ', '  ']),
  };
}
