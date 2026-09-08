// The Rust binaries Bestie builds and ships beside the app.

/// A native binary that builds and ships alongside the app.
sealed class Sidecar {
  const Sidecar({
    required this.name,
    required this.crate,
    required this.version,
    required this.noticeName,
    required this.binaries,
  });

  /// The name the build script is asked for.
  final String name;

  /// The cargo package.
  final String crate;

  /// The pinned version. Bump deliberately, then regenerate the notices.
  final String version;

  /// The file this sidecar's licenses are written to, under
  /// `assets/third_party_licenses/`.
  final String noticeName;

  /// The executables the build produces, without any `.exe` suffix.
  final List<String> binaries;
}

/// A published crate installed from crates.io into the agent shell's `bin`.
final class CratesIOSidecar extends Sidecar {
  const CratesIOSidecar({
    required super.name,
    required super.crate,
    required super.version,
    required super.noticeName,
    required super.binaries,
    this.featureArgs = const [],
  });

  /// Feature selection, which decides what actually gets linked and so
  /// which crates have to be credited.
  final List<String> featureArgs;
}

/// A crate that lives in this repository, built in place and copied into its
/// owning package's native-asset directory.
final class LocalSidecar extends Sidecar {
  const LocalSidecar({
    required super.name,
    required super.crate,
    required super.version,
    required super.noticeName,
    required super.binaries,
    required this.crateDir,
    required this.assetOwner,
  });

  /// Repo-relative directory holding the crate's `Cargo.toml`.
  final String crateDir;

  /// Repo-relative directory of the package whose `assets/native/<os>/<arch>/`
  /// receives the binary.
  final String assetOwner;
}

/// The brush shell Bestie launches as the agent's shell.
const brushSidecar = CratesIOSidecar(
  name: 'brush',
  crate: 'brush-shell',
  version: '0.4.0',
  noticeName: 'brush',
  binaries: ['brush'],
);

/// The uutils multicall supplying `ls` / `cat` / `cp` / … on the shell's PATH.
///
/// `feat_Tier1` is the portable common core plus arch/hostname/nproc/sync/
/// uname/whoami. It deliberately excludes `stdbuf`, which cannot be built via
/// `cargo install` on any platform.
const coreutilsSidecar = CratesIOSidecar(
  name: 'coreutils',
  crate: 'coreutils',
  version: '0.9.0',
  noticeName: 'coreutils',
  binaries: ['coreutils'],
  featureArgs: ['--no-default-features', '--features', 'feat_Tier1'],
);

/// ripgrep, so the agent searches with `rg`.
const ripgrepSidecar = CratesIOSidecar(
  name: 'ripgrep',
  crate: 'ripgrep',
  version: '15.2.0',
  noticeName: 'ripgrep',
  binaries: ['rg'],
);

/// uutils findutils, supplying `find` and `xargs`.
const findutilsSidecar = CratesIOSidecar(
  name: 'findutils',
  crate: 'findutils',
  version: '0.10.0',
  noticeName: 'findutils',
  binaries: ['find', 'xargs'],
);

/// uutils sed, so the agent reads ranges with `sed -n` on every platform.
const sedSidecar = CratesIOSidecar(
  name: 'sed',
  crate: 'sed',
  version: '0.2.0',
  noticeName: 'sed',
  binaries: ['sed'],
);

/// Bestie's own file editor, the program behind the `edit` tool.
const editSidecar = LocalSidecar(
  name: 'edit',
  crate: 'bestie_edit',
  version: '0.1.0',
  noticeName: 'bestie_edit',
  binaries: ['bestie_edit'],
  crateDir: 'packages/infra/bestie_edit/bestie_edit',
  assetOwner: 'packages/infra/bestie_edit',
);

/// Every sidecar, in the order they are built and their notices generated.
const sidecars = <Sidecar>[
  brushSidecar,
  coreutilsSidecar,
  ripgrepSidecar,
  findutilsSidecar,
  sedSidecar,
  editSidecar,
];
