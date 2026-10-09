import 'dart:ffi';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

final class LlamaModelHandle {
  const LlamaModelHandle({
    required this.pointer,
    required this.vocab,
  });

  final Pointer<llama_model> pointer;
  final Pointer<llama_vocab> vocab;

  /// Returns the model pointer as an integer address for cross-isolate sharing.
  int get pointerAddress => pointer.address;
}
