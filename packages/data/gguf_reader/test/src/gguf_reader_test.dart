import 'dart:typed_data';

import 'package:file/memory.dart';
import 'package:gguf_reader/gguf_reader.dart';
import 'package:test/test.dart';

import 'support/gguf_writer.dart';

void main() {
  late MemoryFileSystem fileSystem;

  setUp(() => fileSystem = MemoryFileSystem.test());

  GgufReadResult readBytes(
    List<int> bytes, {
    int maxInlineArrayLength = 1024,
    int maxStringBytes = 1024 * 1024,
    int maxArrayDepth = 8,
    int windowBytes = 64 * 1024,
  }) {
    fileSystem.file('/model.gguf').writeAsBytesSync(bytes);
    return GgufReader(
      fileSystem: fileSystem,
      maxInlineArrayLength: maxInlineArrayLength,
      maxStringBytes: maxStringBytes,
      maxArrayDepth: maxArrayDepth,
      windowBytes: windowBytes,
    ).read('/model.gguf');
  }

  GgufHeader headerOf(GgufReadResult result) => switch (result) {
    GgufRead(:final header) => header,
    _ => throw StateError('Expected a header, got $result'),
  };

  String malformedReason(GgufReadResult result) => switch (result) {
    GgufMalformed(:final reason) => reason,
    _ => throw StateError('Expected malformed, got $result'),
  };

  GgufWriter llamaWriter({int version = 3, Endian endian = Endian.little}) =>
      GgufWriter(version: version, endian: endian)
        ..put('general.architecture', TestValue.string('llama'))
        ..put('general.name', TestValue.string('Llama 3.2 1B Instruct'))
        ..put('llama.context_length', TestValue.uint32(131072))
        ..tensor('token_embd.weight', [2048, 128256], ggmlType: 12)
        ..tensor('output_norm.weight', [2048], offset: 4096);

  group('GgufReader', () {
    test('reads every scalar value type', () {
      final writer = GgufWriter()
        ..put('u8', TestValue.uint8(250))
        ..put('i8', TestValue.int8(-5))
        ..put('u16', TestValue.uint16(65000))
        ..put('i16', TestValue.int16(-300))
        ..put('u32', TestValue.uint32(4000000000))
        ..put('i32', TestValue.int32(-70000))
        ..put('f32', TestValue.float32(0.5))
        ..put('yes', TestValue.boolean(value: true))
        ..put('no', TestValue.boolean(value: false))
        ..put('s', TestValue.string('héllo'))
        ..put('u64', TestValue.uint64(1 << 40))
        ..put('i64', TestValue.int64(-(1 << 40)))
        ..put('f64', TestValue.float64(1.25));

      final header = headerOf(readBytes(writer.build()));

      GgufValue value(String key) => header.metadata[key]!;
      expect(
        value('u8'),
        isA<GgufInteger>()
            .having((it) => it.value, 'value', 250)
            .having((it) => it.type, 'type', GgufValueType.uint8),
      );
      expect((value('i8') as GgufInteger).value, -5);
      expect((value('u16') as GgufInteger).value, 65000);
      expect((value('i16') as GgufInteger).value, -300);
      expect((value('u32') as GgufInteger).value, 4000000000);
      expect((value('i32') as GgufInteger).value, -70000);
      expect(
        value('f32'),
        isA<GgufFloat>()
            .having((it) => it.value, 'value', 0.5)
            .having((it) => it.type, 'type', GgufValueType.float32),
      );
      expect(
        value('yes'),
        isA<GgufBool>()
            .having((it) => it.value, 'value', isTrue)
            .having((it) => it.type, 'type', GgufValueType.bool),
      );
      expect((value('no') as GgufBool).value, isFalse);
      expect(
        value('s'),
        isA<GgufString>()
            .having((it) => it.value, 'value', 'héllo')
            .having((it) => it.type, 'type', GgufValueType.string),
      );
      expect((value('u64') as GgufInteger).value, 1 << 40);
      expect((value('i64') as GgufInteger).value, -(1 << 40));
      expect(
        value('f64'),
        isA<GgufFloat>()
            .having((it) => it.value, 'value', 1.25)
            .having((it) => it.type, 'type', GgufValueType.float64),
      );
      expect(header.metadata.keys.first, 'u8');
    });

    test('keeps short arrays, including nested ones', () {
      final writer = GgufWriter()
        ..put(
          'numbers',
          TestValue.array(5, [TestValue.int32(1), TestValue.int32(-2)]),
        )
        ..put('names', TestValue.strings(['a', 'b']))
        ..put(
          'nested',
          TestValue.array(9, [
            TestValue.array(0, [TestValue.uint8(7)]),
          ]),
        );

      final header = headerOf(readBytes(writer.build()));

      final numbers = header.metadata['numbers']! as GgufArray;
      expect(numbers.type, GgufValueType.array);
      expect(numbers.elementType, GgufValueType.int32);
      expect(
        [
          for (final element in numbers.elements)
            (element as GgufInteger).value,
        ],
        [1, -2],
      );
      final names = header.metadata['names']! as GgufArray;
      expect(
        [
          for (final element in names.elements) (element as GgufString).value,
        ],
        ['a', 'b'],
      );
      final nested = header.metadata['nested']! as GgufArray;
      final inner = nested.elements.single as GgufArray;
      expect((inner.elements.single as GgufInteger).value, 7);
    });

    test('steps over long arrays and keeps reading after them', () {
      final writer = GgufWriter()
        ..put(
          'tokenizer.ggml.tokens',
          TestValue.strings([
            for (var index = 0; index < 50; index++) 't$index',
          ]),
        )
        ..put(
          'tokenizer.ggml.token_type',
          TestValue.array(5, [
            for (var index = 0; index < 50; index++) TestValue.int32(index),
          ]),
        )
        ..put(
          'nested',
          TestValue.array(9, [
            for (var index = 0; index < 20; index++)
              TestValue.array(8, [TestValue.string('x$index')]),
          ]),
        )
        ..put('after', TestValue.string('still here'));

      final header = headerOf(
        readBytes(writer.build(), maxInlineArrayLength: 10, windowBytes: 32),
      );

      expect(
        header.metadata['tokenizer.ggml.tokens'],
        isA<GgufSkippedArray>()
            .having((it) => it.length, 'length', 50)
            .having((it) => it.elementType, 'elementType', GgufValueType.string)
            .having((it) => it.type, 'type', GgufValueType.array),
      );
      expect(
        header.metadata['tokenizer.ggml.token_type'],
        isA<GgufSkippedArray>().having(
          (it) => it.elementType,
          'elementType',
          GgufValueType.int32,
        ),
      );
      expect(
        header.metadata['nested'],
        isA<GgufSkippedArray>().having((it) => it.length, 'length', 20),
      );
      expect(header.stringValue('after'), 'still here');
    });

    test('reads tensor infos and the counts derived from them', () {
      final bytes = llamaWriter().build();

      final header = headerOf(readBytes(bytes));

      expect(header.version, 3);
      expect(header.isBigEndian, isFalse);
      expect(header.tensors, hasLength(2));
      final embedding = header.tensors.first;
      expect(embedding.name, 'token_embd.weight');
      expect(embedding.dimensions, [2048, 128256]);
      expect(embedding.ggmlType, 12);
      expect(embedding.offset, 0);
      expect(embedding.elementCount, 2048 * 128256);
      expect(header.tensors.last.offset, 4096);
      expect(header.parameterCount, 2048 * 128256 + 2048);
      expect(header.alignment, 32);
      expect(
        header.headerByteLength,
        lessThanOrEqualTo(header.tensorDataOffset),
      );
      expect(header.tensorDataOffset % 32, 0);
      expect(header.tensorDataOffset, bytes.length - 64);
    });

    test('honours general.alignment', () {
      final writer = llamaWriter()
        ..put('general.alignment', TestValue.uint32(64));

      final header = headerOf(readBytes(writer.build()));

      expect(header.alignment, 64);
      expect(header.tensorDataOffset % 64, 0);
      expect(header.tensorDataOffset - header.headerByteLength, lessThan(64));
    });

    test('reads version 2 files', () {
      final header = headerOf(readBytes(llamaWriter(version: 2).build()));

      expect(header.version, 2);
      expect(header.architecture, 'llama');
      expect(header.tensors, hasLength(2));
    });

    test('reads big-endian version 3 files', () {
      final writer = llamaWriter(endian: Endian.big)
        ..put('general.sampling.temp', TestValue.float32(0.75));

      final header = headerOf(readBytes(writer.build()));

      expect(header.isBigEndian, isTrue);
      expect(header.version, 3);
      expect(header.contextLength, 131072);
      expect(header.sampling.temperature, 0.75);
      expect(header.tensors.first.dimensions, [2048, 128256]);
    });

    test('reads strings larger than its read window', () {
      final template = 'x' * 500;
      final writer = GgufWriter()
        ..put('tokenizer.chat_template', TestValue.string(template))
        ..put('after', TestValue.uint8(1));

      final header = headerOf(readBytes(writer.build(), windowBytes: 16));

      expect(header.chatTemplate, template);
      expect(header.intValue('after'), 1);
    });

    test('reads each file of a split model on its own', () {
      for (var index = 0; index < 2; index++) {
        final writer = GgufWriter()
          ..put('split.no', TestValue.uint16(index))
          ..put('split.count', TestValue.uint16(2))
          ..put('split.tensors.count', TestValue.int32(3))
          ..tensor('blk.$index.weight', [4, 4]);
        fileSystem
            .file('/model-0000${index + 1}-of-00002.gguf')
            .writeAsBytesSync(writer.build());
      }
      final reader = GgufReader(fileSystem: fileSystem);

      final first = headerOf(reader.read('/model-00001-of-00002.gguf'));
      final second = headerOf(reader.read('/model-00002-of-00002.gguf'));

      expect(first.splitIndex, 0);
      expect(second.splitIndex, 1);
      expect(first.splitCount, 2);
      expect(second.splitTensorCount, 3);
      expect(
        second.split,
        isA<GgufSplit>()
            .having((it) => it.index, 'index', 1)
            .having((it) => it.count, 'count', 2)
            .having((it) => it.tensorCount, 'tensorCount', 3),
      );
      expect(second.tensors.single.name, 'blk.1.weight');
      expect(first.parameterCount, 16);
      expect(headerOf(readBytes(llamaWriter().build())).split, isNull);
    });
  });

  group('GgufReader malformed input', () {
    /// An array holding one array holding one array, [depth] levels deep,
    /// written without recursion so any depth can be built.
    List<int> nestedArrays(int depth) =>
        (GgufWriter()..put(
              'deep',
              TestValue(9, (bytes) {
                for (var level = 1; level < depth; level++) {
                  bytes
                    ..uint32(9)
                    ..uint64(1);
                }
                bytes
                  ..uint32(0)
                  ..uint64(0);
              }),
            ))
            .build();

    test('reads arrays nested up to the depth limit', () {
      for (final maxInlineArrayLength in [1, 0]) {
        final header = headerOf(
          readBytes(
            nestedArrays(3),
            maxArrayDepth: 3,
            maxInlineArrayLength: maxInlineArrayLength,
          ),
        );

        expect(header.metadata['deep'], isNotNull);
      }
    });

    test('rejects arrays nested past the depth limit', () {
      for (final maxInlineArrayLength in [1, 0]) {
        expect(
          malformedReason(
            readBytes(
              nestedArrays(4),
              maxArrayDepth: 3,
              maxInlineArrayLength: maxInlineArrayLength,
            ),
          ),
          contains('nests deeper than 3 levels'),
          reason: 'maxInlineArrayLength $maxInlineArrayLength',
        );
      }
    });

    test('rejects absurdly deep arrays instead of overflowing the stack', () {
      for (final maxInlineArrayLength in [1, 0]) {
        expect(
          readBytes(
            nestedArrays(200000),
            maxInlineArrayLength: maxInlineArrayLength,
          ),
          isA<GgufMalformed>(),
        );
      }
    });

    test('rejects a bad magic', () {
      final bytes = llamaWriter().build(magic: [0x47, 0x47, 0x4D, 0x4C]);

      expect(malformedReason(readBytes(bytes)), contains('bad magic'));
    });

    test('rejects unsupported versions', () {
      for (final version in [1, 4]) {
        final bytes = llamaWriter(version: version).build();

        expect(
          malformedReason(readBytes(bytes)),
          'Unsupported GGUF version $version.',
        );
      }
    });

    test('reports every truncation point as malformed', () {
      final bytes = llamaWriter().build();
      final headerLength = headerOf(readBytes(bytes)).headerByteLength;

      for (var cut = 0; cut < headerLength; cut++) {
        expect(
          readBytes(bytes.sublist(0, cut)),
          isA<GgufMalformed>(),
          reason: 'cut at $cut',
        );
      }
    });

    test('reports a truncated skipped array', () {
      final writer = GgufWriter()
        ..put(
          'big',
          TestValue.array(10, [
            for (var index = 0; index < 8; index++) TestValue.uint64(index),
          ]),
        );
      final bytes = writer.build();
      final arrayEnd = bytes.length - 64 - (bytes.length - 64) % 32;

      final result = readBytes(
        bytes.sublist(0, arrayEnd - 70),
        maxInlineArrayLength: 2,
      );

      expect(malformedReason(result), startsWith('Truncated'));
    });

    test('rejects unknown value types', () {
      final writer = GgufWriter()..put('mystery', TestValue(13, (_) {}));

      expect(
        malformedReason(readBytes(writer.build())),
        startsWith('Unknown value type 13'),
      );
    });

    test('rejects strings over the size limit', () {
      final writer = GgufWriter()..put('long', TestValue.string('x' * 100));

      expect(
        malformedReason(readBytes(writer.build(), maxStringBytes: 99)),
        contains('exceeds the 99 byte limit'),
      );
    });

    test('rejects counts that overflow a signed 64-bit int', () {
      final writer = GgufWriter()
        ..put(
          'huge',
          TestValue(9, (bytes) {
            bytes
              ..uint32(0)
              ..raw(List.filled(8, 0xFF));
          }),
        );

      expect(
        malformedReason(readBytes(writer.build())),
        contains('out of range'),
      );
    });

    test('rejects tensors with more than four dimensions', () {
      final writer = GgufWriter()..tensor('cube', [1, 2, 3, 4, 5]);

      expect(
        malformedReason(readBytes(writer.build())),
        contains('has 5 dimensions'),
      );
    });

    test('rejects an alignment that is not a power of two', () {
      for (final alignment in [0, 24]) {
        final writer = llamaWriter()
          ..put('general.alignment', TestValue.uint32(alignment));

        expect(
          malformedReason(readBytes(writer.build())),
          'general.alignment must be a power of two, got $alignment.',
        );
      }
    });
  });

  group('GgufReader unreadable input', () {
    test('reports a missing file', () {
      final result = GgufReader(fileSystem: fileSystem).read('/missing.gguf');

      expect(
        result,
        isA<GgufUnreadable>().having(
          (it) => it.reason,
          'reason',
          contains('/missing.gguf'),
        ),
      );
    });

    test('reports a directory', () {
      fileSystem.directory('/models').createSync();

      expect(
        GgufReader(fileSystem: fileSystem).read('/models'),
        isA<GgufUnreadable>(),
      );
    });
  });

  test('GgufValueType ids match the GGUF spec', () {
    expect(
      [for (final type in GgufValueType.values) type.id],
      [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
      ],
    );
    expect(GgufValueType.fromId(10), GgufValueType.uint64);
    expect(GgufValueType.fromId(99), isNull);
  });
}
