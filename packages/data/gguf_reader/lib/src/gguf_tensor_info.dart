import 'package:intentions/intentions.dart';

/// Where and how one tensor is stored. The tensor data itself is never read.
@model
final class GgufTensorInfo {
  const GgufTensorInfo({
    required this.name,
    required this.dimensions,
    required this.ggmlType,
    required this.offset,
  });

  final String name;

  final List<int> dimensions;

  /// The raw `ggml_type` id, e.g. 12 for Q4_K.
  final int ggmlType;

  /// Byte offset relative to the start of the tensor data section.
  final int offset;

  int get elementCount =>
      dimensions.fold(1, (product, dimension) => product * dimension);
}
