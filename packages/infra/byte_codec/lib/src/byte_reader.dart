import 'dart:typed_data';

/// Reads primitives out of bytes, little-endian to match `ByteWriter`, with a
/// settable [offset] because the formats this serves are read by seeking to
/// where an index says a record begins.
class ByteReader {
  /// A reader over [bytes], starting at [offset].
  ByteReader(Uint8List bytes, [this.offset = 0])
    : _bytes = bytes,
      _data = ByteData.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );

  final Uint8List _bytes;
  final ByteData _data;

  /// Where the next read will start.
  int offset;

  /// Bytes between here and the end.
  int get remaining => _bytes.length - offset;

  /// Whether there is nothing left to read.
  bool get isEmpty => remaining <= 0;

  /// Whether there is anything left to read.
  bool get isNotEmpty => remaining > 0;

  /// Reads one byte.
  int byte() => _bytes[offset++];

  /// Reads a 16-bit unsigned value.
  int uint16() {
    final value = _data.getUint16(offset, Endian.little);
    offset += 2;
    return value;
  }

  /// Reads a 32-bit unsigned value.
  int uint32() {
    final value = _data.getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  /// Reads a 64-bit unsigned value.
  int uint64() {
    final value = _data.getUint64(offset, Endian.little);
    offset += 8;
    return value;
  }

  /// Reads an unsigned LEB128 varint.
  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final group = _bytes[offset++];
      result |= (group & 0x7F) << shift;
      if (group & 0x80 == 0) return result;
      shift += 7;
    }
  }

  /// Reads [length] bytes as a view of the ones the reader was given, which
  /// nothing writes to — so unlike the writer's view, this one keeps.
  Uint8List bytes(int length) {
    if (offset + length > _bytes.length) {
      throw RangeError.range(length, 0, remaining, 'length');
    }
    final view = Uint8List.sublistView(_bytes, offset, offset + length);
    offset += length;
    return view;
  }

  /// Moves past [count] bytes without reading them, stopping at the end — so
  /// a structure claiming to be longer than it is reads as finished rather
  /// than as having room left over.
  void skip(int count) {
    final at = offset + count;
    offset = at > _bytes.length ? _bytes.length : at;
  }
}
