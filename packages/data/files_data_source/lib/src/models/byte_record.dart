import 'dart:typed_data';

import 'package:intentions/intentions.dart';

/// One record of a recording.
@model
final class ByteRecord {
  const ByteRecord({
    required this.body,
    required this.note,
    required this.units,
  });

  /// The record itself.
  final Uint8List body;

  /// Whatever belongs beside it. Empty is a legal and cheap answer.
  final Uint8List note;

  /// What the writer declared this record weighs, in whatever it measured.
  final int units;
}
