import 'package:files_data_source/src/files_data_source.dart';
import 'package:intentions/intentions.dart';

bool isUtf8Continuation(int byte) => (byte & 0xC0) == 0x80;

int utf8SequenceLength(int lead) {
  if (lead < 0x80) return 1;
  if ((lead & 0xE0) == 0xC0) return 2;
  if ((lead & 0xF0) == 0xE0) return 3;
  if ((lead & 0xF8) == 0xF0) return 4;
  return 1;
}

int alignDown(List<int> bytes, int index) {
  var at = index.clamp(0, bytes.length);
  while (at > 0 && at < bytes.length && isUtf8Continuation(bytes[at])) {
    at--;
  }
  return at;
}

int alignUp(List<int> bytes, int index) {
  var at = index.clamp(0, bytes.length);
  while (at < bytes.length && isUtf8Continuation(bytes[at])) {
    at++;
  }
  return at;
}

@PartOf(FilesDataSource)
class Utf8Window {
  const Utf8Window({required this.start, required this.end});

  final int start;
  final int end;
  int get length => end - start;
  bool get isEmpty => end <= start;
}

Utf8Window utf8Window(List<int> bytes) {
  final start = alignUp(bytes, 0);
  var end = bytes.length;
  var lead = end - 1;
  var scanned = 0;
  while (lead >= start && scanned < 4 && isUtf8Continuation(bytes[lead])) {
    lead--;
    scanned++;
  }
  if (lead >= start && lead + utf8SequenceLength(bytes[lead]) > end) {
    end = lead;
  }
  return Utf8Window(start: start, end: end < start ? start : end);
}
