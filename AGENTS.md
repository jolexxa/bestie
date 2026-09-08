# AGENTS

We value contributions from our robot friends — we just ask that they carefully and thoughtfully adhere to the best practices listed below.

## Code Quality

We prefer code that embodies clear, concise mental models. We prefer to think deeply about the problem we are solving and find the solution that best fits.

- Example 1: a file with many boolean variables might be implemented more cleanly as a state machine (using a bloc, cubit, or other package/pattern).
- Example 2: a file with a series of complex async operations may be better described as a series of stream transforms, an observable primitive, or even a composite.

If you recognize a key insight that would clean something up but do not have what you need on hand to implement it, please just say so. Adding a package reference is easy.

Our criteria for good code also enables us to achieve 100% test coverage.

Good code has...

- as few branches as possible
- injectable dependencies
- well-named identifiers
- no sibling dependencies in the same architectural layer

To avoid sibling dependencies, state must either be lifted up to a common ancestor and passed down, or pushed down and subscribed to.

See README.md for full development setup and contributing guidelines.

We are in the process of exterminating all record types in the codebase. If you work on a file with record types, please help me identify and remove them.

## Testing

When writing tests, write tests that assert the code does what it *should* do, not what it actually does.

We employ mocktail for mocking dependencies of systems under test. We only use custom fake objects when we cannot mock (such as FFI boundaries). We do not spin up real dependencies in tests -- only mocks or fakes.

We use the right tool for the job when testing: mocking (mocktail), clock (time), fakeAsync, platform, etc.

## Developer Scripts

Melos owns workspace orchestration. Run commands from the repo root.

```bash
dart pub get                                   # install workspace dependencies
dart run melos run test --no-select           # run Dart tests
dart run melos run analyze --no-select        # dart analyze --fatal-infos
dart run melos run format --no-select         # format root tools and packages
dart run melos run format:check --no-select   # CI formatting check
dart run melos run coverage --no-select       # tests + lcov coverage report
dart run melos run codegen --no-select        # build_runner code generation
dart run melos run ffigen --no-select         # standard ffigen packages
dart run melos run ffigen_posix_macos         # POSIX macOS bindings
dart run melos run ffigen_posix_linux         # POSIX Linux bindings
dart run melos run build:spawner              # build the spawner PTY helper (Rust, POSIX only)
dart run melos run build:sidecars             # build every Rust sidecar (brush, coreutils, ripgrep, findutils, sed, bestie_edit)
dart run melos run build:edit                 # build just bestie_edit (also build:brush, build:coreutils, build:ripgrep, build:findutils, build:sed)
dart run melos run checks:edit                # cargo fmt / clippy / test for the bestie_edit crate
dart run melos run checks:guard               # cargo fmt / clippy / test for the bestie_guard sandbox crate
dart run melos run setup                      # full fresh-clone bootstrap (host-aware; see below)
dart run melos run checks --no-select         # full CI check sequence
dart run melos run credits                    # regenerate CREDITS.md from shipped dependencies
```

## Tool Calls

Tool calls span across the architecture layers to support extensibility and composition of the app at the highest level. A tool call that goes to the background (i.e., becomes a job) owns its output until the conversation ends.

## Native Binaries

See [APP_ASSETS.md](APP_ASSETS.md) for how shipped files work end to end: the app-asset manifest, the native-asset build hooks, where generated vs vendored assets live, and how a release bundle is assembled. Read it before adding or moving one.

Native libraries for FFI packages are not checked into git — the one exception is vendored files under the repo-root `assets/`, which is the only place a shipped binary may be committed. After cloning, run:

```bash
dart tool/download_curl_assets.dart         # curl-impersonate native libs
dart tool/download_openconsole_assets.dart  # Windows console host (conpty.dll + OpenConsole.exe)
dart run melos run build:spawner            # `spawner` PTY helper (Rust → packages/ffi/posix_spawner/assets/native/<os>/<arch>/spawner)
dart run melos run build:sidecars           # brush, coreutils, ripgrep, findutils, sed (Rust → packages/infra/agent_shell/assets/native/<os>/<arch>/shell/bin)
                                            # and bestie_edit (Rust → packages/infra/bestie_edit/assets/native/<os>/<arch>/bestie_edit)
```

Or just `dart run melos run setup` (→ `tool/setup.dart`) for the whole fresh-clone sequence: submodules, deps, native assets, sidecars (spawner plus everything `build:sidecars` covers), codegen. It is host-platform-aware.

Without these, FFI-dependent tests and features will be skipped or unavailable. `spawner` is required by `process_host_posix` / `agentic_terminal` / the embedded shell — integration test harnesses in those packages refuse to run if it's missing. (`process_host` itself is platform-free and needs nothing native.)

On Windows, `download_curl_assets.dart` needs `--os windows` (the macOS/Linux archives carry symlinked libraries Windows `tar` cannot extract, so the script would fail before reaching the Windows build); `setup` passes this for you. `build:spawner` is POSIX-only and can be skipped.

> **Platform note:** in `packages/ffi/posix_dart/lib/src/bindings/linux_bindings.dart` the POSIX surface (`posix_spawnp`, PTY, etc.) resolves at runtime. Development on Linux has been infrequent, be sure to regenerate against current system headers on a Linux host with:
>
> ```bash
> dart run melos run ffigen_posix_linux
> ```

## Third Party / External

We have a directory that you may clone packages into to take a look, ./external. Sometimes it's helpful to see the code you're trying to hook up to.

## About

Bestie is a terminal chat app that runs against hosted, OpenAI-compatible inference endpoints — OpenRouter and Fireworks AI are built in, and one custom OpenAI-compatible endpoint (a local llama.cpp server, say) can be configured — with API keys and a `provider:model` id in `~/.bestie/bestie.json`. Model facts the endpoint leaves out come from the models.dev catalog, cached under `~/.bestie/cache`. Bestie supports tool calls, reasoning models, parallel subagents, and conversation compaction.

## Agents

Do not make commits unless specifically granted permission to. Never include a co-author. Follow conventional commits, keep descriptions minimal.

## Writing

Comments should never reference other code, only describe what is happening when it is not clear. Otherwise, non-documentation comments are not needed.

## Refactoring

Boyscout rule applies: if you see something that can be improved, even if it's not directly related to the change you're making, please feel free to clean it up. Leave it better than you found it.

We are also attempting to clean up our logic block states where possible and needed (see /logicblocks skill) and embrace clean, layered architecture (see /architecture skill). As this project grows, it's become very important to carefully design systems that play well together and have clear mental models with carefully scoped boundaries. We do not make exceptions for layered architecture and are actively seeking to hunt leaking abstractions (see /hunt-leaks skill).

We are moving away from exceptions in favor of per-operation custom result types using Dart's sealed classes, such as DownloadSucceeded or DownloadChecksumFailed, etc. New code will favor custom result types wherever possible. This ties in nicely with our state machines.

Please don't make commits unless asked. You are welcome to break things up into phases or steps, but we'll take care of the commits.
