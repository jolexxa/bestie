// Just extensions

extension StringTrimming on String {
  /// Strips leading newline characters (\n, \r).
  String stripLeadingNewlines() {
    var start = 0;
    while (start < length) {
      final char = this[start];
      if (char == '\n' || char == '\r') {
        start += 1;
      } else {
        break;
      }
    }
    return start == 0 ? this : substring(start);
  }

  /// Strips leading and trailing newline characters (\n, \r).
  String stripEdgeNewlines() => stripLeadingNewlines()._stripTrailingNewlines();

  String _stripTrailingNewlines() {
    var end = length;
    while (end > 0) {
      final char = this[end - 1];
      if (char == '\n' || char == '\r') {
        end -= 1;
      } else {
        break;
      }
    }
    return end == length ? this : substring(0, end);
  }
}
