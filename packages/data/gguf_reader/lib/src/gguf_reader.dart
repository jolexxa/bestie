import 'dart:convert';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:gguf_reader/src/gguf_byte_source.dart';
import 'package:gguf_reader/src/gguf_header.dart';
import 'package:gguf_reader/src/gguf_read_result.dart';
import 'package:gguf_reader/src/gguf_tensor_info.dart';
import 'package:gguf_reader/src/gguf_value.dart';
import 'package:intentions/intentions.dart';

/// Reads the header of a GGUF file: magic, version, metadata and tensor
/// infos. Tensor data is never read, and arrays longer than
/// [maxInlineArrayLength] (tokenizer vocabularies, merges) are stepped over
/// rather than kept. Arrays nested deeper than [maxArrayDepth] make the file
/// malformed.
///
/// Reads are synchronous, so scanning many files belongs off the UI isolate.
@dataSource
class GgufReader {
  const GgufReader({
    FileSystem fileSystem = const LocalFileSystem(),
    this.maxInlineArrayLength = 1024,
    this.maxStringBytes = 16 * 1024 * 1024,
    this.maxArrayDepth = 8,
    this.windowBytes = 64 * 1024,
  }) : _fileSystem = fileSystem;

  static const _magic = [0x47, 0x47, 0x55, 0x46];
  static const _supportedVersions = {2, 3};
  static const _maxDimensions = 4;
  static const _defaultAlignment = 32;

  final FileSystem _fileSystem;
  final int maxInlineArrayLength;
  final int maxStringBytes;
  final int maxArrayDepth;
  final int windowBytes;

  GgufReadResult read(String path) {
    try {
      final file = _fileSystem.file(path).openSync();
      try {
        return GgufRead(
          _header(GgufByteSource(file, windowBytes: windowBytes)),
        );
      } on FormatException catch (error) {
        return GgufMalformed(error.message);
      } finally {
        file.closeSync();
      }
    } on FileSystemException catch (error) {
      return GgufUnreadable('${error.message}: $path');
    }
  }

  GgufHeader _header(GgufByteSource source) {
    _expectMagic(source);
    final version = _version(source);
    final tensorCount = _count(source);
    final metadataCount = _count(source);
    final metadata = <String, GgufValue>{
      for (var index = 0; index < metadataCount; index++)
        _string(source): _value(source, _type(source)),
    };
    final tensors = [
      for (var index = 0; index < tensorCount; index++) _tensor(source),
    ];
    return GgufHeader(
      version: version,
      isBigEndian: source.endian == Endian.big,
      metadata: metadata,
      tensors: tensors,
      headerByteLength: source.position,
      alignment: _alignment(metadata),
    );
  }

  void _expectMagic(GgufByteSource source) {
    final magic = source.bytes(_magic.length);
    for (var index = 0; index < _magic.length; index++) {
      if (magic[index] != _magic[index]) {
        throw const FormatException('Not a GGUF file: bad magic.');
      }
    }
  }

  int _version(GgufByteSource source) {
    final bytes = ByteData.sublistView(source.bytes(4));
    final little = bytes.getUint32(0, Endian.little);
    if (_supportedVersions.contains(little)) return little;
    final big = bytes.getUint32(0);
    if (!_supportedVersions.contains(big)) {
      throw FormatException('Unsupported GGUF version $little.');
    }
    source.endian = Endian.big;
    return big;
  }

  int _count(GgufByteSource source) {
    final offset = source.position;
    final count = source.uint64();
    if (count < 0) {
      throw FormatException('Count at offset $offset is out of range.');
    }
    return count;
  }

  GgufValueType _type(GgufByteSource source) {
    final offset = source.position;
    final id = source.uint32();
    return GgufValueType.fromId(id) ??
        (throw FormatException('Unknown value type $id at offset $offset.'));
  }

  String _string(GgufByteSource source) {
    final offset = source.position;
    final length = _count(source);
    if (length > maxStringBytes) {
      throw FormatException(
        'String of $length bytes at offset $offset exceeds the '
        '$maxStringBytes byte limit.',
      );
    }
    return utf8.decode(source.bytes(length), allowMalformed: true);
  }

  GgufValue _value(
    GgufByteSource source,
    GgufValueType type, {
    int depth = 0,
  }) => switch (type) {
    GgufValueType.uint8 => GgufInteger(type, source.uint8()),
    GgufValueType.int8 => GgufInteger(type, source.int8()),
    GgufValueType.uint16 => GgufInteger(type, source.uint16()),
    GgufValueType.int16 => GgufInteger(type, source.int16()),
    GgufValueType.uint32 => GgufInteger(type, source.uint32()),
    GgufValueType.int32 => GgufInteger(type, source.int32()),
    GgufValueType.uint64 => GgufInteger(type, source.uint64()),
    GgufValueType.int64 => GgufInteger(type, source.int64()),
    GgufValueType.float32 => GgufFloat(type, source.float32()),
    GgufValueType.float64 => GgufFloat(type, source.float64()),
    GgufValueType.bool => GgufBool(value: source.uint8() != 0),
    GgufValueType.string => GgufString(_string(source)),
    GgufValueType.array => _array(source, depth + 1),
  };

  GgufValue _array(GgufByteSource source, int depth) {
    _expectDepth(source, depth);
    final elementType = _type(source);
    final length = _count(source);
    if (length > maxInlineArrayLength) {
      _skipValues(source, elementType, length, depth);
      return GgufSkippedArray(elementType, length);
    }
    return GgufArray(elementType, [
      for (var index = 0; index < length; index++)
        _value(source, elementType, depth: depth),
    ]);
  }

  void _expectDepth(GgufByteSource source, int depth) {
    if (depth <= maxArrayDepth) return;
    throw FormatException(
      'Array at offset ${source.position} nests deeper than $maxArrayDepth '
      'levels.',
    );
  }

  void _skipValues(
    GgufByteSource source,
    GgufValueType type,
    int count,
    int depth,
  ) {
    switch (type.fixedSize) {
      case final int size:
        source.skipValues(count, size);
      case null:
        for (var index = 0; index < count; index++) {
          _skipVariableValue(source, type, depth);
        }
    }
  }

  void _skipVariableValue(
    GgufByteSource source,
    GgufValueType type,
    int depth,
  ) => switch (type) {
    GgufValueType.string => source.skip(_count(source)),
    _ => _skipArray(source, depth + 1),
  };

  void _skipArray(GgufByteSource source, int depth) {
    _expectDepth(source, depth);
    _skipValues(source, _type(source), _count(source), depth);
  }

  GgufTensorInfo _tensor(GgufByteSource source) {
    final name = _string(source);
    final dimensionCount = source.uint32();
    if (dimensionCount > _maxDimensions) {
      throw FormatException(
        'Tensor "$name" has $dimensionCount dimensions; at most '
        '$_maxDimensions are allowed.',
      );
    }
    return GgufTensorInfo(
      name: name,
      dimensions: [
        for (var index = 0; index < dimensionCount; index++) _count(source),
      ],
      ggmlType: source.uint32(),
      offset: source.uint64(),
    );
  }

  int _alignment(Map<String, GgufValue> metadata) {
    final alignment = switch (metadata['general.alignment']) {
      GgufInteger(:final value) => value,
      _ => _defaultAlignment,
    };
    if (alignment <= 0 || alignment & (alignment - 1) != 0) {
      throw FormatException(
        'general.alignment must be a power of two, got $alignment.',
      );
    }
    return alignment;
  }
}
