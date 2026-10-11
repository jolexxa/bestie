/// Finds the position of the closing brace `}` matching the one at [start].
///
/// Returns null if [start] doesn't point to `{` or no matching brace is found.
/// Correctly handles JSON string escaping and nested braces.
int? findMatchingBrace(String text, int start) {
  if (start >= text.length || text.codeUnitAt(start) != 0x7B /* { */ ) {
    return null;
  }

  var depth = 0;
  var inString = false;
  var escape = false;

  for (var i = start; i < text.length; i++) {
    final codeUnit = text.codeUnitAt(i);

    if (escape) {
      escape = false;
      continue;
    }

    if (codeUnit == 0x5C /* \ */ && inString) {
      escape = true;
      continue;
    }

    if (codeUnit == 0x22 /* " */ ) {
      inString = !inString;
      continue;
    }

    if (inString) continue;

    if (codeUnit == 0x7B /* { */ ) {
      depth++;
    } else if (codeUnit == 0x7D /* } */ ) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}
