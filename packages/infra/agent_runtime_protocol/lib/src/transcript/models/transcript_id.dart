import 'package:dart_mappable/dart_mappable.dart';
import 'package:uuid/uuid.dart';

part 'transcript_id.mapper.dart';

@MappableClass(hook: TranscriptIdHook())
final class TranscriptId with TranscriptIdMappable {
  const TranscriptId(this.value);

  factory TranscriptId.v7() => TranscriptId(const Uuid().v7obj());

  final UuidValue value;
}

@MappableClass(hook: TranscriptEntryIdHook())
final class TranscriptEntryId with TranscriptEntryIdMappable {
  const TranscriptEntryId(this.value);

  factory TranscriptEntryId.v7() => TranscriptEntryId(const Uuid().v7obj());

  final UuidValue value;
}

@MappableClass(hook: TranscriptBlockIdHook())
final class TranscriptBlockId with TranscriptBlockIdMappable {
  const TranscriptBlockId(this.value);

  factory TranscriptBlockId.v7() => TranscriptBlockId(const Uuid().v7obj());

  final UuidValue value;
}

@MappableClass()
final class TranscriptBlockRef with TranscriptBlockRefMappable {
  const TranscriptBlockRef({required this.entryId, required this.blockId});

  final TranscriptEntryId entryId;
  final TranscriptBlockId blockId;
}

abstract class _UuidIdHook<T> extends MappingHook {
  const _UuidIdHook();

  T wrap(UuidValue value);

  @override
  Object? beforeDecode(Object? value) {
    if (value is String) {
      return wrap(UuidValue.withValidation(value));
    }
    return value;
  }

  @override
  Object? beforeEncode(Object? value) {
    return switch (value) {
      TranscriptId(:final value) => value.uuid,
      TranscriptEntryId(:final value) => value.uuid,
      TranscriptBlockId(:final value) => value.uuid,
      _ => value,
    };
  }
}

final class TranscriptIdHook extends _UuidIdHook<TranscriptId> {
  const TranscriptIdHook();

  @override
  TranscriptId wrap(UuidValue value) => TranscriptId(value);
}

final class TranscriptEntryIdHook extends _UuidIdHook<TranscriptEntryId> {
  const TranscriptEntryIdHook();

  @override
  TranscriptEntryId wrap(UuidValue value) => TranscriptEntryId(value);
}

final class TranscriptBlockIdHook extends _UuidIdHook<TranscriptBlockId> {
  const TranscriptBlockIdHook();

  @override
  TranscriptBlockId wrap(UuidValue value) => TranscriptBlockId(value);
}
