import 'package:intentions/intentions.dart';

/// How much text a file holds, by both measures.
@model
final class TextExtent {
  const TextExtent({required this.lines, required this.bytes});

  final int lines;
  final int bytes;
}
