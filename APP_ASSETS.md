# App Assets

Bestie ships a number of files next to its compiled binary — a handful of native libraries, sidecar binaries (such as `bestie_edit` for editing files on disk safely, `bestie_server` for local inference, and `spawner` for initializing processes correctly), certificate bundles for `curl_impersonate`, and credits.

All of these sidecar files vary subtly per-platform, so Bestie provides an app asset pipeline to make sure everything makes it into the final build correctly.

## The two mechanisms

Assets travel by one of two independent paths. Knowing which one an asset uses
explains most of its behaviour.

**1. The app-asset manifest** — bestie's own resolution. Every shipped file is
declared once as an `AppAsset` in `packages/bestie/lib/src/app/assets/app_assets.dart`,
and `AppAssetResolver` turns that declaration into exactly one path for the
current run. This is what the app uses to locate things: `DynamicLibrary.open`
targets, the CA bundle, the shell userland.

**2. Dart's native-assets machinery** — `hook/build.dart` + `package:code_assets`.
Two packages participate: `curl_impersonate_dart`, which the app ships, and
`llama_cpp_dart`, which ships with the `bestie_server` executable. Each hook
copies every native library out of `assets/native/<os>/<arch>/` into
the hook's output directory and registers each as a
`CodeAsset(linkMode: DynamicLoadingBundled())`. The Dart VM materializes those
into `.dart_tool/lib/`.

These two do **not** meet. The app resolves manifest paths into the *source
tree*, never into `.dart_tool/lib/`. The native-assets copies exist alongside,
and because the VM loads those libraries into the process by name, any
transitively-imported sibling is already resolved by the time bestie opens the
library by absolute path. That resilience is real but incidental; don't remove a
hook assuming only bundling depends on it.

`posix_dart`'s hook is intentionally empty (libc is already in every POSIX
process; the hook only satisfies the `code_assets` contract). `packages/bestie/hook/build.dart`
is not an asset hook at all — it runs the architecture validator.

## Where assets live in the source tree

Three kinds of location, distinguished by who writes them and whether git tracks
them.

### Generated, per-package — `packages/**/assets/`, gitignored

The normal case. A tool downloads or builds them; `assets/native/**` is ignored
in each owning package. `dart run melos run clean:assets` deletes these whole
directories, and `melos run setup` regenerates them.

| Asset                                                | Owning package                       | Produced by                                             |
|------------------------------------------------------|--------------------------------------|---------------------------------------------------------|
| `libcurl-impersonate.*`                              | `packages/ffi/curl_impersonate_dart` | `tool/download_curl_assets.dart`                        |
| `llama*`, `ggml*`, `mtmd` (+ Windows runtimes)       | `packages/ffi/llama_cpp_dart`        | `tool/download_llama_assets.dart`                       |
| `cacert.pem`                                         | `packages/ffi/curl_impersonate_dart` | `tool/download_cert_assets.dart`                        |
| `conpty.dll`, `OpenConsole.exe`                      | `packages/ffi/win32_dart`            | `tool/download_openconsole_assets.dart`                 |
| `spawner` (PTY helper)                               | `packages/ffi/posix_spawner`         | `tool/build_spawner.dart` (Rust, POSIX only)            |
| `shell/bin` (brush, coreutils, rg, find, xargs, sed) | `packages/infra/agent_shell`         | `tool/build_sidecar.dart --all` (or one name at a time) |
| `bestie_edit` (the `create` and `edit` tools)        | `packages/infra/bestie_edit`         | `tool/build_sidecar.dart edit` (Rust, in-repo crate)    |

The llama.cpp libraries come from the hobbyfarm-ai/llama.cpp release pinned in
`packages/ffi/llama_cpp_dart/llama_release.txt`, alongside the header snapshot
ffigen binds against (`third_party/include/`, committed). On Windows the release
archive also carries the LLVM OpenMP runtime (`libomp.dll`) that `ggml` links
against; it is staged like any other library from the archive. The MSVC C++
runtime is not in any archive, so the tool copies it from Visual Studio (via
`vswhere`) on a Windows host; `--from-build <dir>` stages a local CMake build of
the fork instead. A `--from-build` set only suits the machine that built it
(its search path points at the build directory), so never ship one. The
libraries ship with the `bestie_server` executable rather than the app, so
bestie's app-asset manifest does not declare them one by one: they reach the
bundle through `bestie_server`'s own `dart build cli`.

### Vendored, repo root — `assets/`, committed

Files the repo owns because no tool can reliably source them. `clean:assets`
never touches this directory, and nothing under `packages/**/assets/` should
ever be committed — if you find yourself writing a `.gitignore` negation to keep
a file there, it belongs here instead.

- `assets/third_party_licenses/` — licence texts for native dependencies that
  have no pub package to harvest from. `tool/build_licenses.dart` combines these
  with the Dart dependency licences into `build/THIRD_PARTY_LICENSES.txt`.

### Generated, repo root — committed

- `CREDITS.md` — fully generated by `tool/credits.dart`, but committed so it is
  reviewable in diffs. Ships at the bundle root (`bundleSubdir: ''`).

## Declaring an asset

```dart
conptyLibrary: AppAsset(
  path: 'conpty.dll',
  packageOwner: 'packages/ffi/win32_dart',
  bundleUnit: AssetBundleUnit.ownerNativeDir,
  missingMessage: 'Console host library (conpty.dll) not found. Run ...',
),
```

- **`path`** — the leaf, relative to whatever base the resolver computes. May be
  a subdirectory (`shell/bin`) or empty (the base directory itself).
- **`packageOwner`** — repo-relative directory of the owning package. `null`
  means a repo-root file (`CREDITS.md`).
- **`isPlatformSpecific`** — `true` (default) resolves under
  `assets/native/<os>/<arch>/`; `false` under a flat `assets/` (`cacert.pem`).
- **`bundleSubdir`** — where it lands in a release bundle. `'lib'` by default,
  `''` for the bundle root.
- **`bundleUnit`** — `assetPath` copies exactly this file or directory;
  `ownerNativeDir` copies the entire `assets/native/<os>/<arch>/` directory it
  lives in, so co-located siblings ship without being enumerated;
  `ownerCliBundle` builds the owning package's `sourceScript` with
  `dart build cli` and merges that bundle in (see below).
- **`sourceScript`** — for a program written in Dart, the repo-relative script
  a source checkout runs (`dart run <script>`) in place of the built
  executable. `AppAssetResolver.commandFor` picks one or the other.
- **`missingMessage`** — shown when resolution fails. Make it actionable: name
  the exact command that produces the file, and keep it accurate — these are the
  instructions someone follows at 2am.

## Resolution: dev vs release

`AppAssetResolver` is deterministic — one path per asset, no candidate search,
no fallback ladder. `bundled` (from `dart.vm.product`, injected at the
composition root) picks the branch:

```
bundled:  <executableDir>/../<bundleSubdir>/<path>
source:   <repoRoot>/<packageOwner>/assets/native/<os>/<arch>/<path>   # platform-specific
          <repoRoot>/<packageOwner>/assets/<path>                      # not platform-specific
          <repoRoot>/<path>                                            # no packageOwner
```

`resolve()` throws a `StateError` carrying `missingMessage` plus the exact path
it looked at. `pathFor()` computes without checking existence.

`bestie_server` resolves its llama.cpp libraries the same way, from an
`AppAsset` with an empty `path` owned by `packages/ffi/llama_cpp_dart`: the
staged `assets/native/<os>/<arch>/` directory in a source checkout, and the
bundle's `lib/` (`bin/../lib`) when bundled. It opens `llama` and
`llama-common` from there, and ggml registers its backends from the same
directory. On macOS the bundled libraries find each other through the install
names `dart build cli` rewrites (`@rpath/lib/<name>`, with the executable's
`@executable_path/..` rpath); on Linux through the release's `$ORIGIN` runpath.
A Windows DLL only searches beside the executable and on `PATH` for the DLLs it
imports, so the server's llama backend points the process's DLL directory
(`SetDllDirectoryW`) at the library folder before it opens anything.

## Packaging a release

`tool/bundle_assets.dart <bundle_dir>` stages a bundle, driven entirely by the
target's `bundleAssets` manifest — the same list the app resolves at runtime, so
there is no hand-maintained copy list to drift. It builds two resolvers (a source
one and a bundled one), copies per each asset's `bundleUnit`, then verifies every
declared asset actually landed and fails loudly listing any that didn't.

`bestie_server` is the one `ownerCliBundle` asset. `dart build cli` wipes its
output and builds one entry point per run, so the server can't share bestie's
build. The bundler builds it into a sibling directory
(`build/cli/<platform>/bestie_server/bundle`) and merges every file into
bestie's bundle: the executable into `bin/` and the llama.cpp libraries the
`llama_cpp_dart` hook produced into `lib/`. A merged file may match one already
there but never replaces a different one. The llama hook bundles whatever is
staged, and nothing when nothing is, so the bundler also checks `lib/` for the
libraries the server can't run without (`tool/src/llama_release.dart`:
`llama`, `llama-common`, `ggml`, `ggml-base`, plus `libomp.dll` and the MSVC
runtime on Windows).

A finished bundle looks something like this (macOS shown):

```
bundle/
  bin/
    bestie
    bestie_server
  lib/
    libcurl-impersonate.dylib
    libllama.dylib, libllama-common.dylib, libggml*.dylib, libmtmd.dylib
      (each also under its versioned names)
    cacert.pem
    spawner
    bestie_edit
    shell/bin/...
  CREDITS.md
  LICENSE.md
  THIRD_PARTY_LICENSES.txt
  install_portable.sh   (local builds only)
```

The hook copies each versioned symlink of a llama.cpp library as a file, so
the bundle carries every name the libraries refer to each other by.

Shipping targets are `macos-arm64`, `linux-x64`, and `windows-x64`. Windows
arm64 is not supported.

## Adding a new asset

1. Produce it into the owning package's `assets/` (a `tool/` script), and ignore
   it there. If it can't be produced, vendor it at the repo root instead.
2. Declare it as an `AppAsset` in `app_assets.dart` with an actionable
   `missingMessage`.
3. If it's a native library that must be loadable by name, confirm the owning
   package has a `hook/build.dart` that picks it up.
4. If it needs a licence shipped, drop the text in
   `assets/third_party_licenses/`.
5. Add it to `tool/clean_assets.dart` if it's a new generated directory, and to
   `tool/setup.dart` if a fresh clone needs it.
6. Run `dart tool/bundle_assets.dart <tmp>` — the verify pass tells you
   immediately if the bundle can't find it.
