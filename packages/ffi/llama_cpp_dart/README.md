# llama_cpp_dart

Dart FFI bindings for the [hobbyfarm-ai/llama.cpp](https://github.com/hobbyfarm-ai/llama.cpp)
fork, including its `best_fit` memory predictor (exported from `llama-common`).

- `llama_release.txt` pins the fork release the bindings and libraries match.
- `third_party/include/` is the header snapshot ffigen binds against.
- `lib/src/bindings/llama_cpp_bindings.dart` is generated from it
  (`dart run ffigen --config tool/ffigen.yaml`).
- `assets/native/<os>/<arch>/` holds the staged libraries (gitignored).

From the repo root:

```sh
dart tool/download_llama_assets.dart                        # pinned release, this host
dart tool/download_llama_assets.dart --from-build <dir>     # a local CMake build of the fork
dart tool/update_llama.dart <tag>                           # bump the pin, headers, bindings, libraries
```

```dart
final runtime = LlamaCpp.open(libraryPath: '/path/to/libllama.0.dylib');
final common = LlamaCpp.open(libraryPath: '/path/to/libllama-common.0.dylib');
```
