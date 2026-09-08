import 'package:characters/characters.dart';
import 'package:termunicode/termunicode.dart' as termunicode;

/// Lookup table of single-character strings for the ASCII range.
/// `String.fromCharCode(n)` allocates a new one-char String every
/// call; using this const table means printing ASCII into cells
/// never allocates.
const List<String> _asciiStrings = [
  '\u0000',
  '\u0001',
  '\u0002',
  '\u0003',
  '\u0004',
  '\u0005',
  '\u0006',
  '\u0007',
  '\u0008',
  '\u0009',
  '\u000A',
  '\u000B',
  '\u000C',
  '\u000D',
  '\u000E',
  '\u000F',
  '\u0010',
  '\u0011',
  '\u0012',
  '\u0013',
  '\u0014',
  '\u0015',
  '\u0016',
  '\u0017',
  '\u0018',
  '\u0019',
  '\u001A',
  '\u001B',
  '\u001C',
  '\u001D',
  '\u001E',
  '\u001F',
  ' ',
  '!',
  '"',
  '#',
  r'$',
  '%',
  '&',
  "'",
  '(',
  ')',
  '*',
  '+',
  ',',
  '-',
  '.',
  '/',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  ':',
  ';',
  '<',
  '=',
  '>',
  '?',
  '@',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '[',
  r'\',
  ']',
  '^',
  '_',
  '`',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
  '{',
  '|',
  '}',
  '~',
  '\u007F',
];

/// Returns the shared const String for [codePoint] if it's in the
/// ASCII range; otherwise allocates a fresh one via
/// [String.fromCharCode].
String stringForCodePoint(int codePoint) {
  if (codePoint < 128) return _asciiStrings[codePoint];
  return String.fromCharCode(codePoint);
}

/// Compute the display width (in grid columns) of a grapheme
/// cluster. Returns 0 for zero-width clusters (combining marks,
/// variation selectors, zero-width joiners on their own), 1 for
/// the common case, and 2 for East Asian wide / fullwidth / wide
/// emoji clusters.
int graphemeWidth(String cluster) {
  if (cluster.isEmpty) return 0;
  if (isCombiningOrZeroWidth(cluster.runes.first)) return 0;
  final w = termunicode.widthString(cluster);
  if (w >= 2) return 2;
  return 1;
}

/// `true` if [codePoint] is a combining mark, variation
/// selector, or other zero-width formatter.
bool isCombiningOrZeroWidth(int codePoint) {
  if (codePoint <= 0xA0) return false;
  return termunicode.widthCp(codePoint) == 0;
}

/// Given a buffer of accumulated code points, split into complete
/// grapheme clusters using `package:characters` (UAX #29). Returns
/// all-but-the-last cluster as `complete` and keeps the last in
/// `tail` — it might still extend (e.g. a base letter waiting for
/// a combining mark, or a ZWJ emoji waiting for the joined char).
({List<String> complete, String tail}) splitBufferedGraphemes(
  String buffer,
) {
  if (buffer.isEmpty) return (complete: const <String>[], tail: '');
  final iter = buffer.characters.iterator;
  final complete = <String>[];
  String? previous;
  while (iter.moveNext()) {
    if (previous != null) complete.add(previous);
    previous = iter.current;
  }
  return (complete: complete, tail: previous ?? '');
}

/// Flush every cluster in [buffer] as complete — none held back.
/// Used when a non-print event (CSI, OSC, etc.) arrives and we
/// must commit whatever is pending before the cursor jumps.
List<String> flushBufferedGraphemes(String buffer) {
  if (buffer.isEmpty) return const <String>[];
  return buffer.characters.toList();
}
