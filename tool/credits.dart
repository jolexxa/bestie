// To run:
// dart tool/credits.dart          # writes CREDITS.md
//
// CREDITS.md is fully generated. The set of third-party Dart packages is
// auto-detected from the bestie binary's runtime dependency closure (so a new
// dependency can never be silently un-credited), and each package's license
// and copyright are read from its bundled LICENSE/NOTICE text. Native
// libraries and special attributions — which are not pub packages and cannot
// be auto-detected — are listed by hand in [_manualDeps].
//
// The run prints a review summary: any package whose license could not be
// classified, or whose copyright could not be found, is flagged so it can be
// given an override in [_licenseOverrides] / [_copyrightOverrides].

import 'dart:io';

import 'src/helpers.dart';
import 'src/shipped_packages.dart';

/// License buckets, in the display order used for the generated file.
enum License {
  mit,
  bsd2,
  bsd3,
  isc,
  apache2,
  mpl2,
  zlib,
  bsl,
  unlicense,
  curl,
  other,
}

String _licenseName(License l) => switch (l) {
  License.mit => 'MIT',
  License.bsd2 => 'BSD-2-Clause',
  License.bsd3 => 'BSD-3-Clause',
  License.isc => 'ISC',
  License.apache2 => 'Apache-2.0',
  License.mpl2 => 'MPL-2.0',
  License.zlib => 'Zlib',
  License.bsl => 'BSL-1.0',
  License.unlicense => 'Unlicense',
  License.curl => 'curl',
  License.other => 'Other',
};

String _licenseUrl(License l) => switch (l) {
  License.mit => 'https://opensource.org/licenses/MIT',
  License.bsd2 => 'https://opensource.org/licenses/BSD-2-Clause',
  License.bsd3 => 'https://opensource.org/licenses/BSD-3-Clause',
  License.isc => 'https://opensource.org/licenses/ISC',
  License.apache2 => 'https://www.apache.org/licenses/LICENSE-2.0',
  License.mpl2 => 'https://mozilla.org/MPL/2.0/',
  License.zlib => 'https://opensource.org/license/Zlib',
  License.bsl => 'https://www.boost.org/LICENSE_1_0.txt',
  License.unlicense => 'https://unlicense.org/',
  License.curl => 'https://curl.se/docs/copyright.html',
  License.other => 'https://spdx.org/licenses/',
};

/// A credited component.
class Dep {
  Dep(this.name, this.license, this.copyright, {this.url, this.note});

  final String name;
  final License license;
  final String copyright;
  final String? url;

  /// When set, the dependency is rendered as its own `###` block above the
  /// table (used for shipped native libraries and derived-code attributions).
  final String? note;
}

// ---------------------------------------------------------------------------
// Hand-listed: native libraries and special attributions.
//
// These ship inside the native binaries (or are models/data, or are code Bestie's
// logic is derived from) and are not pub packages, so they cannot be
// auto-detected. Keep this list current when bumping native dependencies.
// ---------------------------------------------------------------------------

final _manualDeps = <Dep>[
  // -- Derived code / models ----------------------------------------------
  Dep(
    'curl-impersonate',
    License.mit,
    'lexiforest and contributors',
    url: 'https://github.com/lexiforest/curl-impersonate',
    note:
        'Bestie ships the `curl-impersonate` native libraries for '
        'browser-impersonating HTTP requests.',
  ),
  Dep(
    'Mozilla CA Certificate Store',
    License.mpl2,
    'Mozilla Foundation and contributors',
    url: 'https://curl.se/ca/cacert.pem',
    note:
        'Bestie bundles the Mozilla root CA certificate store (cacert.pem, as '
        'extracted and published by the curl project) so its HTTPS client '
        'verifies TLS peers consistently across platforms. The data is '
        'available under the MPL-2.0 and, per the CCADB Data Usage Terms, the '
        'Community Data License Agreement - Permissive, Version 2.0, which '
        'requires attribution to the Common CA Database (CCADB).',
  ),

  // -- Native libraries bundled inside curl-impersonate --------------------
  Dep(
    'BoringSSL',
    License.apache2,
    'Google LLC',
    url: 'https://github.com/google/boringssl',
  ),
  Dep(
    'brotli',
    License.mit,
    'The Brotli Authors',
    url: 'https://github.com/google/brotli',
  ),
  Dep(
    'nghttp2',
    License.mit,
    'Tatsuhiro Tsujikawa and contributors',
    url: 'https://github.com/nghttp2/nghttp2',
  ),
  Dep(
    'nghttp3',
    License.mit,
    'ngtcp2 contributors',
    url: 'https://github.com/ngtcp2/nghttp3',
  ),
  Dep(
    'ngtcp2',
    License.mit,
    'ngtcp2 contributors',
    url: 'https://github.com/ngtcp2/ngtcp2',
  ),
  Dep(
    'zstd',
    License.bsd3,
    'Meta Platforms, Inc.',
    url: 'https://github.com/facebook/zstd',
  ),
  Dep(
    'zlib',
    License.zlib,
    'Jean-loup Gailly and Mark Adler',
    url: 'https://github.com/madler/zlib',
  ),
  Dep(
    'curl / libcurl',
    License.curl,
    'Daniel Stenberg and contributors',
    url: 'https://curl.se/',
  ),

  Dep(
    'Windows Terminal / OpenConsole',
    License.mit,
    'Microsoft Corporation',
    url: 'https://github.com/microsoft/terminal',
    note:
        "Bestie ships Microsoft's redistributable ConPTY — `conpty.dll` and the "
        '`OpenConsole.exe` console host it launches.',
  ),

  // -- Native helper (spawner PTY helper, Rust) ----------------------------
  Dep(
    'libc',
    License.mit,
    'The Rust Project Developers',
    url: 'https://github.com/rust-lang/libc',
    note:
        'The `libc` Rust crate (used by Bestie\'s `spawner` PTY helper) is '
        'dual-licensed under MIT or Apache-2.0; Bestie distributes it under the '
        'MIT terms.',
  ),

  // -- Confined agent shell and editor (Rust) ------------------------------
  Dep(
    'brush',
    License.mit,
    'reuben olinsky',
    url: 'https://github.com/reubeno/brush',
    note:
        'Bestie ships the `brush` shell as the userland its agent runs commands '
        'in. brush links its Rust dependencies statically, so the licence of '
        'every crate inside the shipped binary is reproduced in '
        'THIRD_PARTY_LICENSES.txt.',
  ),
  Dep(
    'uutils coreutils',
    License.mit,
    'uutils developers',
    url: 'https://github.com/uutils/coreutils',
    note:
        'Bestie ships the uutils `coreutils` multicall, which supplies `ls` / '
        '`cat` / `cp` / … on the agent shell\'s PATH. It links its Rust '
        'dependencies statically, so the licence of every crate inside the '
        'shipped binary is reproduced in THIRD_PARTY_LICENSES.txt.',
  ),
  Dep(
    'ripgrep',
    License.mit,
    'Andrew Gallant',
    url: 'https://github.com/BurntSushi/ripgrep',
    note:
        'Bestie ships `rg` so its agent can search files from the shell. '
        'ripgrep is dual-licensed under MIT or the Unlicense; Bestie '
        'distributes it under the MIT terms. It links its Rust dependencies '
        'statically, so the licence of every crate inside the shipped binary '
        'is reproduced in THIRD_PARTY_LICENSES.txt.',
  ),
  Dep(
    'uutils findutils',
    License.mit,
    'uutils developers',
    url: 'https://github.com/uutils/findutils',
    note:
        'Bestie ships the uutils `find` and `xargs` on the agent shell\'s '
        'PATH. They link their Rust dependencies statically, so the licence '
        'of every crate inside the shipped binaries is reproduced in '
        'THIRD_PARTY_LICENSES.txt.',
  ),
  Dep(
    'uutils sed',
    License.mit,
    'uutils developers',
    url: 'https://github.com/uutils/sed',
    note:
        'Bestie ships the uutils `sed` on the agent shell\'s PATH so ranges '
        'of a file read the same on every platform. It links its Rust '
        'dependencies statically, so the licence of every crate inside the '
        'shipped binary is reproduced in THIRD_PARTY_LICENSES.txt.',
  ),
];

// Overrides for auto-detected Dart packages whose LICENSE text does not carry
// a machine-readable copyright line (common for Apache-2.0), or which are
// misclassified. Keep small — most packages need no entry.

const _copyrightOverrides = <String, String>{
  // Apache-2.0 / MPL packages whose generic license text carries no
  // machine-readable copyright line. Holders verified from package metadata.
  'rxdart': 'ReactiveX',
  'quiver': 'Google',
  'hotreloader': 'vegardit.com',
  'trafilatura': 'Hugging Face SAS',
  'charset': 'shirne.com',
  'arxlib': 'JinZr',
  'system_info2': 'onepub.dev',
  'clock': 'the Dart project authors',
  'decimal': 'a14n',
  'rational': 'a14n',
  'logic_blocks': 'Joanna May',
};

const _licenseOverrides = <String, License>{};

Future<void> main() async {
  final root = repoRoot().path;
  final missing = <String>[];

  final shipped = await resolveShippedDartPackages(
    repoRoot: root,
    appPackagePath: '$root/packages/bestie',
    missing: missing,
  );

  final unclassified = <String>[];
  final noCopyright = <String>[];

  final deps = <Dep>[..._manualDeps];
  for (final pkg in shipped) {
    final licenseFile = pkg.licenseFile;
    final text = licenseFile?.readAsStringSync() ?? '';

    var license = _licenseOverrides[pkg.name] ?? _classifyLicense(text);
    if (license == License.other) unclassified.add(pkg.name);

    var copyright = _copyrightOverrides[pkg.name] ?? _extractCopyright(text);
    if (copyright == null) {
      noCopyright.add(pkg.name);
      copyright = 'See bundled LICENSE / THIRD_PARTY_LICENSES.txt';
    }

    deps.add(Dep(pkg.name, license, copyright, url: _packageUrl(pkg)));
  }

  File('$root/CREDITS.md').writeAsStringSync(_render(deps));

  stdout
    ..writeln(
      'Wrote CREDITS.md '
      '(${_manualDeps.length} hand-listed, ${shipped.length} auto-detected)',
    )
    ..writeln();
  _reportReview('Unclassified license (bucketed as Other)', unclassified);
  _reportReview('No copyright line found (using fallback)', noCopyright);
  _reportReview('Could not locate in pub cache', missing);
}

void _reportReview(String label, List<String> names) {
  if (names.isEmpty) return;
  stdout.writeln('REVIEW — $label:');
  for (final n in (names.toList()..sort())) {
    stdout.writeln('  - $n');
  }
  stdout.writeln();
}

String _render(List<Dep> deps) {
  final buf = StringBuffer()
    ..writeln('# Credits')
    ..writeln()
    ..writeln(
      'Bestie is made possible by the following open-source projects and '
      'models. We are extremely grateful to the authors of these projects.',
    )
    ..writeln();

  final grouped = <License, List<Dep>>{};
  for (final dep in deps) {
    grouped.putIfAbsent(dep.license, () => []).add(dep);
  }

  for (final license in License.values) {
    final group = grouped[license];
    if (group == null || group.isEmpty) continue;

    buf
      ..writeln('## ${_licenseName(license)}')
      ..writeln()
      ..writeln(
        'The following components are licensed under the '
        '[${_licenseName(license)}](${_licenseUrl(license)}).',
      )
      ..writeln();

    final noted = group.where((d) => d.note != null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final table = group.where((d) => d.note == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (final dep in noted) {
      buf
        ..writeln('### ${dep.name}')
        ..writeln()
        ..writeln(dep.note)
        ..writeln();
      if (dep.url != null) buf.writeln('Source: ${dep.url}');
      buf
        ..writeln()
        ..writeln('Copyright ${dep.copyright}.')
        ..writeln();
    }

    if (table.isNotEmpty) {
      buf
        ..writeln('| Package | Copyright |')
        ..writeln('|---------|-----------|');
      for (final dep in table) {
        final name = dep.url != null ? '[${dep.name}](${dep.url})' : dep.name;
        buf.writeln('| $name | ${dep.copyright} |');
      }
      buf.writeln();
    }
  }

  return buf.toString();
}

/// Classifies a LICENSE body into a [License] bucket by distinctive phrases.
License _classifyLicense(String text) {
  final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return License.other;

  if (t.contains('apache license') && t.contains('version 2.0')) {
    return License.apache2;
  }
  if (t.contains('mozilla public license version 2.0')) return License.mpl2;
  if (t.contains('boost software license')) return License.bsl;
  if (t.contains(
    'this is free and unencumbered software released into the '
    'public domain',
  )) {
    return License.unlicense;
  }
  if (t.contains('mit license') ||
      t.contains('permission is hereby granted, free of charge')) {
    return License.mit;
  }
  if (t.contains('redistribution and use in source and binary forms')) {
    return t.contains('neither the name') ? License.bsd3 : License.bsd2;
  }
  if (t.contains('permission to use, copy, modify, and/or distribute') ||
      t.contains('isc license')) {
    return License.isc;
  }
  if (t.contains('altered source versions must be plainly marked') ||
      t.contains('zlib/libpng')) {
    return License.zlib;
  }
  if (t.contains('curl and libcurl are dual-licensed') ||
      (t.contains('permission to use, copy, modify, and distribute') &&
          t.contains('curl'))) {
    return License.curl;
  }
  return License.other;
}

/// Extracts the copyright holder from a LICENSE body, or null if absent.
///
/// Only matches a real copyright *notice* — a line that begins with
/// "Copyright" and is followed by a year — so mentions of "the copyright
/// owner" inside a license body (e.g. Apache-2.0) are never picked up.
String? _extractCopyright(String text) {
  final pattern = RegExp(
    r'^copyright\s*(\(c\)|\(C\)|©)?\s*(?<years>[0-9][0-9,\s\-–—]*[0-9]|[0-9])\s*'
    r'(?<holder>.+)$',
    caseSensitive: false,
  );
  for (final raw in text.split('\n').take(60)) {
    final line = raw.trim();
    final m = pattern.firstMatch(line);
    if (m == null) continue;

    final holder = m
        .namedGroup('holder')!
        // Strip a separator left between the year and the holder ("2013, …").
        .replaceFirst(RegExp(r'^[,\s\-–—]+'), '')
        // Cut a trailing "All rights reserved" clause.
        .split(RegExp(r'[.,]?\s*all rights reserved', caseSensitive: false))
        .first
        // Drop a trailing contact email and any trailing punctuation.
        .replaceFirst(RegExp(r'\s*<[^>]*>'), '')
        .replaceFirst(RegExp(r'[.,\s]+$'), '')
        .trim();
    if (holder.length > 2) return holder;
  }
  return null;
}

/// Prefers the package's declared repository/homepage, else its pub.dev page.
String _packageUrl(ShippedPackage pkg) {
  final pubspec = File('${pkg.baseDir}/pubspec.yaml');
  if (pubspec.existsSync()) {
    for (final key in const ['repository:', 'homepage:']) {
      for (final line in pubspec.readAsLinesSync()) {
        if (line.trimLeft().startsWith(key)) {
          final url = line.split(key).last.trim();
          if (url.startsWith('http')) return url;
        }
      }
    }
  }
  return 'https://pub.dev/packages/${pkg.name}';
}
