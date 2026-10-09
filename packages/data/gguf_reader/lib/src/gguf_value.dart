import 'package:intentions/intentions.dart';

/// The type tag GGUF stores in front of every metadata value.
@model
enum GgufValueType {
  uint8(0, 1),
  int8(1, 1),
  uint16(2, 2),
  int16(3, 2),
  uint32(4, 4),
  int32(5, 4),
  float32(6, 4),
  bool(7, 1),
  string(8, null),
  array(9, null),
  uint64(10, 8),
  int64(11, 8),
  float64(12, 8);

  const GgufValueType(this.id, this.fixedSize);

  /// The numeric id written to the file.
  final int id;

  /// Bytes per value, or null when the size is stored with the value.
  final int? fixedSize;

  static final Map<int, GgufValueType> _byId = {
    for (final type in values) type.id: type,
  };

  /// The type for [id], or null when the id is not part of the format.
  static GgufValueType? fromId(int id) => _byId[id];
}

/// A metadata value read from a GGUF header.
@model
sealed class GgufValue {
  const GgufValue();

  GgufValueType get type;
}

/// Any of the integer types, widened to a Dart [int].
///
/// A `uint64` above 2^63 - 1 wraps to a negative number.
@model
final class GgufInteger extends GgufValue {
  const GgufInteger(this.type, this.value);

  @override
  final GgufValueType type;

  final int value;
}

/// A `float32` or `float64`.
@model
final class GgufFloat extends GgufValue {
  const GgufFloat(this.type, this.value);

  @override
  final GgufValueType type;

  final double value;
}

@model
final class GgufBool extends GgufValue {
  const GgufBool({required this.value});

  @override
  GgufValueType get type => GgufValueType.bool;

  final bool value;
}

@model
final class GgufString extends GgufValue {
  const GgufString(this.value);

  @override
  GgufValueType get type => GgufValueType.string;

  final String value;
}

/// An array small enough to keep in memory.
@model
final class GgufArray extends GgufValue {
  const GgufArray(this.elementType, this.elements);

  @override
  GgufValueType get type => GgufValueType.array;

  final GgufValueType elementType;

  final List<GgufValue> elements;
}

/// An array too long to keep, such as a tokenizer vocabulary. Only its
/// shape is known.
@model
final class GgufSkippedArray extends GgufValue {
  const GgufSkippedArray(this.elementType, this.length);

  @override
  GgufValueType get type => GgufValueType.array;

  final GgufValueType elementType;

  final int length;
}
