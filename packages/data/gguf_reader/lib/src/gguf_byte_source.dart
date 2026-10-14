import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:gguf_reader/src/gguf_reader.dart';
import 'package:intentions/intentions.dart';

/// Sequential reads over a file through a fixed-size window, so a header
/// costs one disk read per window instead of one per field.
///
/// Reading past the end of the file throws a [FormatException].
@PartOf(GgufReader)
class GgufByteSource {
  GgufByteSource(this._file, {required int windowBytes})
    : length = _file.lengthSync(),
      _window = Uint8List(windowBytes);

  final RandomAccessFile _file;
  final Uint8List _window;
  var _windowStart = 0;
  var _windowLength = 0;

  final int length;

  int position = 0;

  Endian endian = Endian.little;

  int get remaining => length - position;

  Uint8List bytes(int count) {
    _require(count);
    if (count > _window.length) return _readDirect(count);
    if (position + count > _windowStart + _windowLength) {
      _file.setPositionSync(position);
      _windowLength = _file.readIntoSync(_window);
      _windowStart = position;
    }
    final offset = position - _windowStart;
    position += count;
    return Uint8List.sublistView(_window, offset, offset + count);
  }

  void skip(int count) {
    _require(count);
    position += count;
  }

  /// Skips [count] values of [size] bytes each.
  void skipValues(int count, int size) {
    if (count > remaining ~/ size) _truncated(count * size);
    position += count * size;
  }

  int uint8() => bytes(1)[0];
  int int8() => _data(1).getInt8(0);
  int uint16() => _data(2).getUint16(0, endian);
  int int16() => _data(2).getInt16(0, endian);
  int uint32() => _data(4).getUint32(0, endian);
  int int32() => _data(4).getInt32(0, endian);
  int uint64() => _data(8).getUint64(0, endian);
  int int64() => _data(8).getInt64(0, endian);
  double float32() => _data(4).getFloat32(0, endian);
  double float64() => _data(8).getFloat64(0, endian);

  ByteData _data(int count) => ByteData.sublistView(bytes(count));

  Uint8List _readDirect(int count) {
    _file.setPositionSync(position);
    position += count;
    return _file.readSync(count);
  }

  void _require(int count) {
    if (count < 0 || count > remaining) _truncated(count);
  }

  Never _truncated(int count) => throw FormatException(
    'Truncated: needed $count bytes at offset $position but only '
    '$remaining remain.',
  );
}
