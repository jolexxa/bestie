import 'package:intentions/intentions.dart';

/// A place in a recording read as one run of characters.
@model
final class RecordCursor {
  const RecordCursor(this.record, this.into);

  /// Where nothing is: the start of a recording with no records in it.
  static const RecordCursor start = RecordCursor(0, 0);

  /// The record holding the character.
  final int record;

  /// Characters into that record.
  final int into;

  @override
  String toString() => 'RecordCursor($record, $into)';
}
