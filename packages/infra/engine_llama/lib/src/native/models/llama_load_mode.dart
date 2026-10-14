import 'package:dart_mappable/dart_mappable.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

part 'llama_load_mode.mapper.dart';

/// How llama.cpp reads model weights from disk.
@MappableEnum()
enum LlamaLoadMode {
  /// Let the backend pick from the device's capabilities.
  auto,

  /// Read the weights into memory without mapping or locking.
  none,

  /// Memory-map the weights file.
  mmap,

  /// Lock the weights in RAM so they are never swapped or compressed.
  mlock,

  /// Memory-map the weights file and lock it in RAM.
  mmapMlock,

  /// Read with direct I/O where the platform supports it.
  directIo;

  /// The native load mode.
  llama_load_mode get native => switch (this) {
    LlamaLoadMode.auto => llama_load_mode.LLAMA_LOAD_MODE_AUTO,
    LlamaLoadMode.none => llama_load_mode.LLAMA_LOAD_MODE_NONE,
    LlamaLoadMode.mmap => llama_load_mode.LLAMA_LOAD_MODE_MMAP,
    LlamaLoadMode.mlock => llama_load_mode.LLAMA_LOAD_MODE_MLOCK,
    LlamaLoadMode.mmapMlock => llama_load_mode.LLAMA_LOAD_MODE_MMAP_MLOCK,
    LlamaLoadMode.directIo => llama_load_mode.LLAMA_LOAD_MODE_DIRECT_IO,
  };
}
