typedef ConfigDecoder<T> = T? Function(Object? raw);
typedef ConfigEncoder<T> = Object? Function(T? value);

final class ConfigCodec<T> {
  const ConfigCodec({required this.decode, required this.encode});

  final ConfigDecoder<T> decode;
  final ConfigEncoder<T> encode;
}

final class ConfigCodecs {
  const ConfigCodecs._();

  static const doubles = ConfigCodec<double>(
    decode: _decodeDouble,
    encode: _identity,
  );

  static const integers = ConfigCodec<int>(
    decode: _decodeInt,
    encode: _identity,
  );

  static const booleans = ConfigCodec<bool>(
    decode: _decodeBool,
    encode: _identity,
  );

  static const strings = ConfigCodec<String>(
    decode: _decodeString,
    encode: _identity,
  );

  static const maps = ConfigCodec<Map<String, Object?>>(
    decode: _decodeMap,
    encode: _identity,
  );

  static const stringLists = ConfigCodec<List<String>>(
    decode: _decodeStringList,
    encode: _identity,
  );
}

double? _decodeDouble(Object? raw) => switch (raw) {
  final num value => value.toDouble(),
  _ => null,
};

int? _decodeInt(Object? raw) => switch (raw) {
  final int value => value,
  final double value when value.isFinite && value == value.roundToDouble() =>
    value.toInt(),
  _ => null,
};

bool? _decodeBool(Object? raw) => raw is bool ? raw : null;

String? _decodeString(Object? raw) => raw is String ? raw : null;

Map<String, Object?>? _decodeMap(Object? raw) => switch (raw) {
  Map<String, Object?>() => raw,
  Map() => raw.cast<String, Object?>(),
  _ => null,
};

List<String>? _decodeStringList(Object? raw) => switch (raw) {
  List<String>() => raw,
  final List<Object?> items when items.every((item) => item is String) =>
    items.cast<String>(),
  _ => null,
};

Object? _identity(Object? value) => value;
