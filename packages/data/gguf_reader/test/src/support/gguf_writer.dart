import 'dart:convert';
import 'dart:typed_data';

/// Builds GGUF bytes field by field.
class GgufBytes {
  GgufBytes(this.endian);

  final Endian endian;
  final _builder = BytesBuilder();

  int get length => _builder.length;

  void raw(List<int> bytes) => _builder.add(bytes);

  void uint8(int value) => raw([value]);
  void int8(int value) => _fixed(1, (data) => data.setInt8(0, value));
  void uint16(int value) =>
      _fixed(2, (data) => data.setUint16(0, value, endian));
  void int16(int value) => _fixed(2, (data) => data.setInt16(0, value, endian));
  void uint32(int value) =>
      _fixed(4, (data) => data.setUint32(0, value, endian));
  void int32(int value) => _fixed(4, (data) => data.setInt32(0, value, endian));
  void uint64(int value) =>
      _fixed(8, (data) => data.setUint64(0, value, endian));
  void int64(int value) => _fixed(8, (data) => data.setInt64(0, value, endian));
  void float32(double value) =>
      _fixed(4, (data) => data.setFloat32(0, value, endian));
  void float64(double value) =>
      _fixed(8, (data) => data.setFloat64(0, value, endian));

  void string(String value) {
    final encoded = utf8.encode(value);
    uint64(encoded.length);
    raw(encoded);
  }

  Uint8List toBytes() => _builder.toBytes();

  void _fixed(int size, void Function(ByteData data) write) {
    final data = ByteData(size);
    write(data);
    raw(data.buffer.asUint8List());
  }
}

/// A typed metadata value to write.
class TestValue {
  const TestValue(this.typeId, this.write);

  factory TestValue.uint8(int value) =>
      TestValue(0, (bytes) => bytes.uint8(value));
  factory TestValue.int8(int value) =>
      TestValue(1, (bytes) => bytes.int8(value));
  factory TestValue.uint16(int value) =>
      TestValue(2, (bytes) => bytes.uint16(value));
  factory TestValue.int16(int value) =>
      TestValue(3, (bytes) => bytes.int16(value));
  factory TestValue.uint32(int value) =>
      TestValue(4, (bytes) => bytes.uint32(value));
  factory TestValue.int32(int value) =>
      TestValue(5, (bytes) => bytes.int32(value));
  factory TestValue.float32(double value) =>
      TestValue(6, (bytes) => bytes.float32(value));
  factory TestValue.boolean({required bool value}) =>
      TestValue(7, (bytes) => bytes.uint8(value ? 1 : 0));
  factory TestValue.string(String value) =>
      TestValue(8, (bytes) => bytes.string(value));
  factory TestValue.uint64(int value) =>
      TestValue(10, (bytes) => bytes.uint64(value));
  factory TestValue.int64(int value) =>
      TestValue(11, (bytes) => bytes.int64(value));
  factory TestValue.float64(double value) =>
      TestValue(12, (bytes) => bytes.float64(value));

  /// An array whose elements all share [elementTypeId].
  factory TestValue.array(int elementTypeId, List<TestValue> elements) =>
      TestValue(9, (bytes) {
        bytes
          ..uint32(elementTypeId)
          ..uint64(elements.length);
        for (final element in elements) {
          element.write(bytes);
        }
      });

  factory TestValue.strings(List<String> values) =>
      TestValue.array(8, [for (final value in values) TestValue.string(value)]);

  final int typeId;
  final void Function(GgufBytes bytes) write;
}

/// Writes a whole GGUF file: header, metadata, tensor infos, padding and
/// placeholder tensor data.
class GgufWriter {
  GgufWriter({this.version = 3, this.endian = Endian.little});

  final int version;
  final Endian endian;
  final _metadata = <String, TestValue>{};
  final _tensors = <_TestTensor>[];

  void put(String key, TestValue value) => _metadata[key] = value;

  void tensor(
    String name,
    List<int> dimensions, {
    int ggmlType = 0,
    int offset = 0,
  }) => _tensors.add(_TestTensor(name, dimensions, ggmlType, offset));

  Uint8List build({List<int> magic = const [0x47, 0x47, 0x55, 0x46]}) {
    final bytes = GgufBytes(endian)
      ..raw(magic)
      ..uint32(version)
      ..uint64(_tensors.length)
      ..uint64(_metadata.length);
    for (final MapEntry(:key, :value) in _metadata.entries) {
      bytes
        ..string(key)
        ..uint32(value.typeId);
      value.write(bytes);
    }
    for (final tensor in _tensors) {
      bytes
        ..string(tensor.name)
        ..uint32(tensor.dimensions.length);
      tensor.dimensions.forEach(bytes.uint64);
      bytes
        ..uint32(tensor.ggmlType)
        ..uint64(tensor.offset);
    }
    while (bytes.length % 32 != 0) {
      bytes.uint8(0);
    }
    bytes.raw(List.filled(64, 0xAB));
    return bytes.toBytes();
  }
}

class _TestTensor {
  const _TestTensor(this.name, this.dimensions, this.ggmlType, this.offset);

  final String name;
  final List<int> dimensions;
  final int ggmlType;
  final int offset;
}
