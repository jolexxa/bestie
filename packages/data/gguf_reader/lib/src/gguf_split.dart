import 'package:intentions/intentions.dart';

/// One shard's place in a model split across several GGUF files.
@model
final class GgufSplit {
  const GgufSplit({required this.index, required this.count, this.tensorCount});

  /// Zero-based position of this shard.
  final int index;

  /// How many shards make up the model.
  final int count;

  /// Tensors across every shard, when the file records it.
  final int? tensorCount;
}
