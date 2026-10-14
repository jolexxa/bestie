// The llama.cpp build bestie ships, pinned.

import 'dart:io';

import 'package:path/path.dart' as p;

/// The fork every release, header and library comes from.
const llamaRepository = 'hobbyfarm-ai/llama.cpp';

/// The FFI package that owns the libraries, the pin and the header snapshot.
const llamaPackageDir = 'packages/ffi/llama_cpp_dart';

/// The file holding the pinned release tag, relative to the repo root.
const llamaReleaseFile = '$llamaPackageDir/llama_release.txt';

/// Where the header snapshot lives, relative to the repo root.
const llamaHeaderDir = '$llamaPackageDir/third_party/include';

/// The headers ffigen binds against, by their path inside the fork.
const llamaHeaders = [
  'include/llama.h',
  'common/best_fit.h',
  'ggml/include/ggml.h',
  'ggml/include/ggml-cpu.h',
  'ggml/include/ggml-backend.h',
  'ggml/include/ggml-alloc.h',
  'ggml/include/ggml-opt.h',
  'ggml/include/gguf.h',
];

/// The pinned release tag, read from [llamaReleaseFile].
String pinnedLlamaTag(String repoRootPath) =>
    File(p.join(repoRootPath, llamaReleaseFile)).readAsStringSync().trim();

/// A release asset download URL for [tag].
Uri llamaAssetUrl(String tag, String assetName) => Uri.parse(
  'https://github.com/$llamaRepository/releases/download/$tag/$assetName',
);

/// Raw content from the fork at [tag], for the header snapshot.
Uri llamaSourceUrl(String tag, String path) =>
    Uri.parse('https://raw.githubusercontent.com/$llamaRepository/$tag/$path');

/// One release archive that contributes libraries to a platform.
final class LlamaVariant {
  const LlamaVariant({required this.label, required this.suffix});

  /// Short name shown while staging (`cpu`, `vulkan`, `metal`).
  final String label;

  /// The asset name's platform suffix, extension included.
  final String suffix;

  /// The release asset name for [tag].
  String assetName(String tag) => 'llama-$tag-bin-$suffix';

  bool get isZip => suffix.endsWith('.zip');
}

/// The MSVC C++ runtime the Windows libraries import, which no archive
/// carries and a stock Windows install may lack.
const msvcRuntimeLibraries = [
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
];

/// The libraries `bestie_server` opens, or that the ones it opens import,
/// named without their platform prefix and extension.
const llamaCoreLibraries = ['llama', 'llama-common', 'ggml', 'ggml-base'];

/// A desktop target bestie ships llama.cpp for.
final class LlamaPlatform {
  const LlamaPlatform({
    required this.os,
    required this.arch,
    required this.libraryPrefix,
    required this.libraryExtension,
    required this.variants,
    this.runtimeLibraries = const [],
  });

  /// The `--os` family and asset folder.
  final String os;

  /// The asset architecture folder.
  final String arch;

  /// What a shared library's file name starts with on this platform.
  final String libraryPrefix;

  /// The shared-library extension on this platform.
  final String libraryExtension;

  /// Archives merged into one directory, first writer wins: the CPU build
  /// comes first, so its core libraries are kept and later archives only add
  /// their backend plugin (`ggml-vulkan`, ...).
  final List<LlamaVariant> variants;

  /// Runtime libraries that must sit beside the llama.cpp libraries because
  /// the host may not have them.
  final List<String> runtimeLibraries;

  /// Whether the libraries import the MSVC C++ runtime.
  bool get needsMsvcRuntime =>
      runtimeLibraries.any(msvcRuntimeLibraries.contains);

  /// Every library a release bundle must carry for `bestie_server` to run.
  List<String> get requiredLibraries => [
    for (final library in llamaCoreLibraries)
      '$libraryPrefix$library$libraryExtension',
    ...runtimeLibraries,
  ];

  /// `<os>/<arch>`, the layout under `assets/native/`.
  String get assetSubdir => '$os/$arch';

  /// Whether [name] is a library to stage. The per-tool `*-impl` libraries
  /// the release also carries are left out.
  bool isLibrary(String name) {
    if (name.contains('-impl.')) return false;
    final lower = name.toLowerCase();
    return lower.endsWith(libraryExtension) ||
        (libraryExtension == '.so' && lower.contains('.so.'));
  }

  /// Whether [name] is a licence file shipped beside the libraries.
  bool isLicense(String name) => name.startsWith('LICENSE');
}

const llamaPlatforms = [
  LlamaPlatform(
    os: 'macos',
    arch: 'arm64',
    libraryPrefix: 'lib',
    libraryExtension: '.dylib',
    variants: [LlamaVariant(label: 'metal', suffix: 'macos-arm64.tar.gz')],
  ),
  LlamaPlatform(
    os: 'linux',
    arch: 'x64',
    libraryPrefix: 'lib',
    libraryExtension: '.so',
    variants: [
      LlamaVariant(label: 'cpu', suffix: 'ubuntu-x64.tar.gz'),
      LlamaVariant(label: 'vulkan', suffix: 'ubuntu-vulkan-x64.tar.gz'),
    ],
  ),
  LlamaPlatform(
    os: 'windows',
    arch: 'x64',
    libraryPrefix: '',
    libraryExtension: '.dll',
    variants: [
      LlamaVariant(label: 'cpu', suffix: 'win-cpu-x64.zip'),
      LlamaVariant(label: 'vulkan', suffix: 'win-vulkan-x64.zip'),
    ],
    runtimeLibraries: ['libomp.dll', ...msvcRuntimeLibraries],
  ),
];
