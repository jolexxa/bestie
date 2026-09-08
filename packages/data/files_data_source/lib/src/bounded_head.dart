import 'package:files_data_source/src/files_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Keeps the leading characters of a stream that is being written out in full,
/// so the head can be handed back while the rest goes to disk.
@PartOf(FilesDataSource)
final class BoundedHead {
  BoundedHead({required int maxChars}) : _room = maxChars;

  final int _room;
  final StringBuffer _buffer = StringBuffer();

  String get text => _buffer.toString();

  /// Offers [line], which is preceded by a newline unless it is [first].
  void add(String line, {required bool first}) {
    final room = _room - _buffer.length;
    if (room <= 0) return;
    _buffer.write(Excerpt.clip(first ? line : '\n$line', room));
  }
}
