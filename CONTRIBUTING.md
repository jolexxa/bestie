# Contributing

Thanks for wrangling Bestie with us. This guide walks through everything needed to get the TUI in `packages/bestie` running locally from a fresh clone.

See [AGENTS.md](./AGENTS.md) for code-quality and testing conventions, and [APP_ASSETS.md](./APP_ASSETS.md) for how shipped native assets work.

## Prerequisites

- [Dart SDK] 3.11+ (the easiest way is to use [FVM] to install Flutter, which includes Dart — without a version manager, you'll end up in a stampede)
- [Rust] (stable) for the native sidecars — the `spawner` PTY helper, `bestie_edit`, and the bundled shell userland

Bestie supports 🪟 Windows x64, 🍎 Apple Silicon, and 🐧 Linux x64.

## 1. Clone with submodules

Bestie has one git submodule, [curl-impersonate], used by its FFI package. The `--recursive` flag pulls it in automatically.

```sh
git clone --recursive git@github.com:jolexxa/bestie.git
cd bestie
```

Already cloned without `--recursive`?

```sh
git submodule update --init --recursive
```

## 2. Bootstrap

Bestie is a Dart workspace managed by Melos. One command installs dependencies, downloads the prebuilt native libraries, builds the Rust sidecars, and runs code generation. It is host-platform-aware.

```sh
dart pub get
dart run melos run setup
```

Without the native assets, FFI-dependent tests and features are skipped or unavailable. The individual steps `setup` runs are listed in [AGENTS.md](./AGENTS.md#native-binaries) if you only need one of them.

> [!NOTE]
> `tool/download_curl_assets.dart` infers the [curl-impersonate] release tag from the submodule's commit. If the submodule is pinned to a commit between releases, inference fails — pass the tag explicitly:
>
> ```sh
> dart tool/download_curl_assets.dart --tag v2.0.0a5
> ```

## 3. Run

For day-to-day development:

```sh
dart run packages/bestie/bin/bestie.dart
```

To produce a bundled CLI binary (matching what CI ships), run `tool/local_build.sh`, which mirrors the `build` job in `.github/workflows/release.yaml`. The bundle lands in `build/cli/<platform>/bundle/` with `bin/bestie` and the native libraries it needs in `lib/`.

The committed tree holds the `0.0.0` dev version; release builds stamp the real one with `dart tool/set_version.dart <version>`.

## Developer scripts

Melos owns workspace orchestration. Run commands from the repo root; the root `pubspec.yaml` is the command index and [AGENTS.md](./AGENTS.md#developer-scripts) lists every script.

```sh
dart run melos run test --no-select           # run Dart tests
dart run melos run analyze --no-select        # dart analyze --fatal-infos
dart run melos run format --no-select         # format root tools and packages
dart run melos run checks --no-select         # full CI check sequence
```

Run `dart run melos run checks --no-select` before pushing. It mirrors what CI runs.

[Dart SDK]: https://dart.dev/get-dart
[FVM]: https://fvm.app/
[Rust]: https://rustup.rs/
[curl-impersonate]: https://github.com/lexiforest/curl-impersonate
