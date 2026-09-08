import 'dart:typed_data';

/// Least a writer's buffer is ever sized at, so a fresh one can take a
/// varint or two before it has to think about growing.
const int _minimumCapacity = 8;

/// Appends primitives to a buffer that grows to fit, little-endian
/// throughout, and that [reset] keeps — so a caller writing many small
/// records pays for the buffer once rather than once a record.
class ByteWriter {
  /// A writer holding [capacity] bytes before it first has to grow.
  ByteWriter([int capacity = 256])
    : _bytes = Uint8List(
        capacity < _minimumCapacity ? _minimumCapacity : capacity,
      ) {
    _data = ByteData.view(_bytes.buffer);
  }

  Uint8List _bytes;
  late ByteData _data;
  int _length = 0;

  /// Bytes written since the last [reset].
  int get length => _length;

  /// Whether nothing has been written since the last [reset].
  bool get isEmpty => _length == 0;

  /// Whether anything has been written since the last [reset].
  bool get isNotEmpty => _length > 0;

  /// Drops what has been written, keeping the buffer for the next record.
  void reset() => _length = 0;

  /// Appends one byte, of which only the low 8 bits are kept.
  void byte(int value) {
    _ensure(1);
    _bytes[_length++] = value;
  }

  /// Appends a 16-bit unsigned value.
  void uint16(int value) {
    _ensure(2);
    _data.setUint16(_length, value, Endian.little);
    _length += 2;
  }

  /// Appends a 32-bit unsigned value.
  void uint32(int value) {
    _ensure(4);
    _data.setUint32(_length, value, Endian.little);
    _length += 4;
  }

  /// Appends a 64-bit unsigned value.
  void uint64(int value) {
    _ensure(8);
    _data.setUint64(_length, value, Endian.little);
    _length += 8;
  }

  /// Appends [value] as an unsigned LEB128 varint — seven bits per byte, low
  /// group first, the high bit set on every byte but the last — so a small
  /// number costs one byte where a fixed width would cost four.
  void varint(int value) {
    assert(value >= 0, 'varint is unsigned; $value cannot be written');
    var remaining = value;
    while (remaining >= 0x80) {
      byte((remaining & 0x7F) | 0x80);
      remaining >>>= 7;
    }
    byte(remaining);
  }

  /// Appends [value] whole.
  void bytes(List<int> value) {
    if (value.isEmpty) return;
    _ensure(value.length);
    _bytes.setRange(_length, _length + value.length, value);
    _length += value.length;
  }

  /// What has been written, backed by the writer's own buffer and so good
  /// only until the next write or [reset].
  Uint8List view() => Uint8List.sublistView(_bytes, 0, _length);

  /// What has been written, copied out and safe to keep.
  Uint8List take() => Uint8List.fromList(view());

  void _ensure(int extra) {
    final needed = _length + extra;
    if (needed <= _bytes.length) return;
    var capacity = _bytes.length * 2;
    while (capacity < needed) {
      capacity *= 2;
    }
    final grown = Uint8List(capacity)..setRange(0, _length, _bytes);
    _bytes = grown;
    _data = ByteData.view(grown.buffer);
  }
}
