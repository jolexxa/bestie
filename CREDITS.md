# Credits

Bestie is made possible by the following open-source projects and models. We are extremely grateful to the authors of these projects.

## MIT

The following components are licensed under the [MIT](https://opensource.org/licenses/MIT).

### brush

Bestie ships the `brush` shell as the userland its agent runs commands in. brush links its Rust dependencies statically, so the licence of every crate inside the shipped binary is reproduced in THIRD_PARTY_LICENSES.txt.

Source: https://github.com/reubeno/brush

Copyright reuben olinsky.

### curl-impersonate

Bestie ships the `curl-impersonate` native libraries for browser-impersonating HTTP requests.

Source: https://github.com/lexiforest/curl-impersonate

Copyright lexiforest and contributors.

### libc

The `libc` Rust crate (used by Bestie's `spawner` PTY helper) is dual-licensed under MIT or Apache-2.0; Bestie distributes it under the MIT terms.

Source: https://github.com/rust-lang/libc

Copyright The Rust Project Developers.

### ripgrep

Bestie ships `rg` so its agent can search files from the shell. ripgrep is dual-licensed under MIT or the Unlicense; Bestie distributes it under the MIT terms. It links its Rust dependencies statically, so the licence of every crate inside the shipped binary is reproduced in THIRD_PARTY_LICENSES.txt.

Source: https://github.com/BurntSushi/ripgrep

Copyright Andrew Gallant.

### uutils coreutils

Bestie ships the uutils `coreutils` multicall, which supplies `ls` / `cat` / `cp` / … on the agent shell's PATH. It links its Rust dependencies statically, so the licence of every crate inside the shipped binary is reproduced in THIRD_PARTY_LICENSES.txt.

Source: https://github.com/uutils/coreutils

Copyright uutils developers.

### uutils findutils

Bestie ships the uutils `find` and `xargs` on the agent shell's PATH. They link their Rust dependencies statically, so the licence of every crate inside the shipped binaries is reproduced in THIRD_PARTY_LICENSES.txt.

Source: https://github.com/uutils/findutils

Copyright uutils developers.

### uutils sed

Bestie ships the uutils `sed` on the agent shell's PATH so ranges of a file read the same on every platform. It links its Rust dependencies statically, so the licence of every crate inside the shipped binary is reproduced in THIRD_PARTY_LICENSES.txt.

Source: https://github.com/uutils/sed

Copyright uutils developers.

### Windows Terminal / OpenConsole

Bestie ships Microsoft's redistributable ConPTY — `conpty.dll` and the `OpenConsole.exe` console host it launches.

Source: https://github.com/microsoft/terminal

Copyright Microsoft Corporation.

| Package | Copyright |
|---------|-----------|
| [ansi_escape_codes](https://github.com/vi-k/ansi_escape_codes) | Victor Dunaev (vi-k, nashol, yet_another_developer) |
| [archive](https://github.com/brendan-duncan/archive) | Brendan Duncan |
| [bloc](https://github.com/felangel/bloc/tree/master/packages/bloc) | Felix Angelov |
| [brotli](https://github.com/google/brotli) | The Brotli Authors |
| [dart_mappable](https://github.com/schultek/dart_mappable) | Kilian Schulte |
| [dart_numerics](https://github.com/zlumyo/dart_numerics) | dart-numerics |
| [ddgs](https://github.com/kamranxdev/ddgs) | kamranxdev |
| [dio](https://github.com/cfug/dio/blob/main/dio) | Wen Du (wendux) |
| [dio_web_adapter](https://github.com/cfug/dio/blob/main/plugins/web_adapter) | Wen Du (wendux) |
| [equatable](https://github.com/felangel/equatable) | Felix Angelov |
| [eval_ex](https://github.com/RobluScouting/EvalEx) | Udo Klimaschewski |
| [fuzzy](https://github.com/comigor/fuzzy) | See bundled LICENSE / THIRD_PARTY_LICENSES.txt |
| [good_intentions](https://github.com/jolexxa/good_intentions/tree/main/good_intentions) | Joanna |
| [highlighting](https://github.com/akvelon/dart-highlighting) | Akvelon Inc |
| [html](https://github.com/dart-lang/tools/tree/main/pkgs/html) | The Authors |
| [humanizer](https://github.com/kentcb/humanizer) | Kent Boogaart |
| [image](https://github.com/brendan-duncan/image) | Brendan Duncan |
| [intentions](https://github.com/jolexxa/good_intentions/tree/main/intentions) | Joanna |
| [intentions_engine](https://github.com/jolexxa/good_intentions/tree/main/intentions_engine) | Joanna |
| [katex_dart](https://github.com/orestesgaolin/katex/tree/main/packages/katex_dart) | Dominik |
| [logger](https://github.com/SourceHorizon/logger) | Simon Leier |
| [nghttp2](https://github.com/nghttp2/nghttp2) | Tatsuhiro Tsujikawa and contributors |
| [nghttp3](https://github.com/ngtcp2/nghttp3) | ngtcp2 contributors |
| [ngtcp2](https://github.com/ngtcp2/ngtcp2) | ngtcp2 contributors |
| [nocterm](https://github.com/Norbert515/nocterm) | Norbert Kozsir |
| [openai_dart](https://github.com/davidmigloz/ai_clients_dart/tree/main/packages/openai_dart) | David Miguel Lozano |
| [openrouter_sdk](https://gitlab.com/hanibachi/openrouter_sdk) | hani bachi |
| [petitparser](https://github.com/petitparser/dart-petitparser) | Lukas Renggli |
| [posix](https://github.com/onepub-dev/dart_posix) | Brett Sutton |
| [quectocolors](https://github.com/timmaffett/quectocolors) | Tim Maffett |
| [stringr](https://github.com/Chinmay-KB/stringr) | Chinmay Kabi |
| [termunicode](https://github.com/kascote/termkit/tree/main/packages/termunicode) | nelson fernandez |
| [time](https://github.com/jogboms/time.dart) | Jeremiah Ogbomo |
| [type_plus](https://github.com/schultek/type_plus) | Kilian Schulte |
| [uuid](https://github.com/Daegalus/dart-uuid) | Yulian Kuncheff |
| [xml](https://github.com/renggli/dart-xml) | Lukas Renggli |
| [yaml](https://github.com/dart-lang/tools/tree/main/pkgs/yaml) | the Dart project authors |
| [zmodem](https://github.com/TerminalStudio/zmodem) | xuty |

## BSD-2-Clause

The following components are licensed under the [BSD-2-Clause](https://opensource.org/licenses/BSD-2-Clause).

| Package | Copyright |
|---------|-----------|
| [tuple](https://github.com/google/tuple.dart) | the tuple project authors |

## BSD-3-Clause

The following components are licensed under the [BSD-3-Clause](https://opensource.org/licenses/BSD-3-Clause).

| Package | Copyright |
|---------|-----------|
| [_fe_analyzer_shared](https://github.com/dart-lang/sdk/tree/main/pkg/_fe_analyzer_shared) | the Dart project authors |
| [analyzer](https://github.com/dart-lang/sdk/tree/main/pkg/analyzer) | the Dart project authors |
| [args](https://github.com/dart-lang/core/tree/main/pkgs/args) | the Dart project authors |
| [async](https://github.com/dart-lang/core/tree/main/pkgs/async) | the Dart project authors |
| [boolean_selector](https://github.com/dart-lang/tools/tree/main/pkgs/boolean_selector) | the Dart project authors |
| [characters](https://github.com/dart-lang/core/tree/main/pkgs/characters) | the Dart project authors |
| [code_assets](https://github.com/dart-lang/native/tree/main/pkgs/code_assets) | the Dart project authors |
| [collection](https://github.com/dart-lang/core/tree/main/pkgs/collection) | the Dart project authors |
| [convert](https://github.com/dart-lang/core/tree/main/pkgs/convert) | the Dart project authors |
| [crypto](https://github.com/dart-lang/core/tree/main/pkgs/crypto) | the Dart project authors |
| [csslib](https://github.com/dart-lang/tools/tree/main/pkgs/csslib) | the Dart project authors |
| [ffi](https://github.com/dart-lang/native/tree/main/pkgs/ffi) | the Dart project authors |
| [file](https://github.com/dart-lang/tools/tree/main/pkgs/file) | the Dart project authors |
| [fixnum](https://github.com/dart-lang/core/tree/main/pkgs/fixnum) | the Dart project authors |
| [glob](https://github.com/dart-lang/tools/tree/main/pkgs/glob) | the Dart project authors |
| [globbing](https://github.com/mezoni/globbing) | Andrew Mezoni |
| [hooks](https://github.com/dart-lang/native/tree/main/pkgs/hooks) | the Dart project authors |
| [http](https://github.com/dart-lang/http/tree/master/pkgs/http) | the Dart project authors |
| [http_parser](https://github.com/dart-lang/http/tree/master/pkgs/http_parser) | the Dart project authors |
| [intl](https://github.com/dart-lang/i18n/tree/main/pkgs/intl) | the Dart project authors |
| [io](https://github.com/dart-lang/tools/tree/main/pkgs/io) | the Dart project authors |
| [logging](https://github.com/dart-lang/core/tree/main/pkgs/logging) | the Dart project authors |
| [markdown](https://github.com/dart-lang/tools/tree/main/pkgs/markdown) | the Dart project authors |
| [matcher](https://github.com/dart-lang/test/tree/master/pkgs/matcher) | the Dart project authors |
| [meta](https://github.com/dart-lang/sdk/tree/main/pkg/meta) | the Dart project authors |
| [mime](https://github.com/dart-lang/tools/tree/main/pkgs/mime) | the Dart project authors |
| [package_config](https://github.com/dart-lang/tools/tree/main/pkgs/package_config) | the Dart project authors |
| [path](https://github.com/dart-lang/core/tree/main/pkgs/path) | the Dart project authors |
| [platform](https://github.com/dart-lang/core/tree/main/pkgs/platform) | the Dart project authors |
| [pub_semver](https://github.com/dart-lang/tools/tree/main/pkgs/pub_semver) | the Dart project authors |
| [record_use](https://github.com/dart-lang/native/tree/main/pkgs/record_use) | the Dart project authors |
| [source_span](https://github.com/dart-lang/tools/tree/main/pkgs/source_span) | the Dart project authors |
| [stack_trace](https://github.com/dart-lang/tools/tree/main/pkgs/stack_trace) | the Dart project authors |
| [stream_channel](https://github.com/dart-lang/tools/tree/main/pkgs/stream_channel) | the Dart project authors |
| [stream_transform](https://github.com/dart-lang/tools/tree/main/pkgs/stream_transform) | the Dart project authors |
| [string_scanner](https://github.com/dart-lang/tools/tree/main/pkgs/string_scanner) | the Dart project authors |
| [system_info2](https://github.com/onepub-dev/system_info) | onepub.dev |
| [term_glyph](https://github.com/dart-lang/tools/tree/main/pkgs/term_glyph) | the Dart project authors |
| [test_api](https://github.com/dart-lang/test/tree/master/pkgs/test_api) | the Dart project authors |
| [typed_data](https://github.com/dart-lang/core/tree/main/pkgs/typed_data) | the Dart project authors |
| [vm_service](https://github.com/dart-lang/sdk/tree/main/pkg/vm_service) | the Dart project authors |
| [watcher](https://github.com/dart-lang/tools/tree/main/pkgs/watcher) | the Dart project authors |
| [web](https://github.com/dart-lang/web) | the Dart project authors |
| [web_socket](https://github.com/dart-lang/http/tree/master/pkgs/web_socket) | the Dart project authors |
| [wikimedia_commons_search](https://github.com/yomio/wikimedia_commons_search.git) | Lukas Nevosad |
| [zstd](https://github.com/facebook/zstd) | Meta Platforms, Inc. |

## Apache-2.0

The following components are licensed under the [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0).

| Package | Copyright |
|---------|-----------|
| [arxlib](https://github.com/JinZr/arxlib.git) | JinZr |
| [BoringSSL](https://github.com/google/boringssl) | Google LLC |
| [charset](https://github.com/shirne/charset-dart) | shirne.com |
| [clock](https://github.com/dart-lang/tools/tree/main/pkgs/clock) | the Dart project authors |
| [dartx](https://github.com/leisim/dartx) | See bundled LICENSE / THIRD_PARTY_LICENSES.txt |
| [decimal](https://github.com/a14n/dart-decimal) | a14n |
| [hotreloader](https://github.com/vegardit/dart-hotreloader.git) | vegardit.com |
| [quiver](https://github.com/google/quiver-dart) | Google |
| [rational](https://github.com/a14n/dart-rational) | a14n |
| [rxdart](https://github.com/ReactiveX/rxdart) | ReactiveX |
| [trafilatura](https://github.com/kamranxdev/trafilatura) | Hugging Face SAS |

## MPL-2.0

The following components are licensed under the [MPL-2.0](https://mozilla.org/MPL/2.0/).

### Mozilla CA Certificate Store

Bestie bundles the Mozilla root CA certificate store (cacert.pem, as extracted and published by the curl project) so its HTTPS client verifies TLS peers consistently across platforms. The data is available under the MPL-2.0 and, per the CCADB Data Usage Terms, the Community Data License Agreement - Permissive, Version 2.0, which requires attribution to the Common CA Database (CCADB).

Source: https://curl.se/ca/cacert.pem

Copyright Mozilla Foundation and contributors.

| Package | Copyright |
|---------|-----------|
| [logic_blocks](https://github.com/kerberjg/logic_blocks.dart) | Joanna May |

## Zlib

The following components are licensed under the [Zlib](https://opensource.org/license/Zlib).

| Package | Copyright |
|---------|-----------|
| [zlib](https://github.com/madler/zlib) | Jean-loup Gailly and Mark Adler |

## curl

The following components are licensed under the [curl](https://curl.se/docs/copyright.html).

| Package | Copyright |
|---------|-----------|
| [curl / libcurl](https://curl.se/) | Daniel Stenberg and contributors |

