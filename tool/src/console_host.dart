// The Windows console host bestie ships, pinned. Two tools have to agree on it:
// the downloader that fetches the binaries, and the notice generator that
// records which release they came from.
//
// Microsoft publishes ConPTY as a redistributable NuGet package attached to
// every Windows Terminal release. It carries `conpty.dll` — the same
// `CreatePseudoConsole` API the inbox console exports, under `Conpty`-prefixed
// names — and the `OpenConsole.exe` it launches instead of the inbox
// `conhost.exe`. That matters: the inbox host repaints its whole viewport
// after a resize and, having no scrollback, paints an orphaned line tail over
// history it already forgot. OpenConsole repositions and redraws only the
// prompt, so nothing is lost.
//
// To bump: pick a microsoft/terminal release, read its
// `Microsoft.Windows.Console.ConPTY.<version>.nupkg` asset name, download it,
// take its SHA-256, and update all four values below. Then rerun
// `dart tool/download_openconsole_assets.dart`, which also rewrites the
// notice file from the same tag.

/// The microsoft/terminal release the package is attached to.
const consoleHostRelease = 'v1.24.11911.0';

/// The NuGet package's own version, which does not track the release tag.
const consoleHostVersion = '1.24.260710001';

/// SHA-256 of the release asset, checked before anything is extracted.
const consoleHostSha256 =
    '9382ad7becb7e4d84e300578d8e4f4df28f43d979d9055d978c42913c47e0e9d';

/// The release asset holding the redistributable.
const consoleHostAsset =
    'Microsoft.Windows.Console.ConPTY.$consoleHostVersion.nupkg';

/// Where the release asset is fetched from.
Uri get consoleHostArchiveUrl => Uri.parse(
  'https://github.com/microsoft/terminal/releases/download/'
  '$consoleHostRelease/$consoleHostAsset',
);

/// Raw content from the terminal repo at the pinned release, for the notices.
Uri consoleHostSourceUrl(String path) => Uri.parse(
  'https://raw.githubusercontent.com/microsoft/terminal/'
  '$consoleHostRelease/$path',
);

/// A file lifted out of the NuGet package.
class ConsoleHostFile {
  const ConsoleHostFile({required this.archivePath, required this.name});

  /// Path inside the package, with `<arch>` standing in for the target.
  final String archivePath;

  /// The name it is installed under.
  final String name;
}

const consoleHostFiles = [
  ConsoleHostFile(
    archivePath: 'runtimes/win-<arch>/native/conpty.dll',
    name: 'conpty.dll',
  ),
  ConsoleHostFile(
    archivePath: 'build/native/runtimes/<arch>/OpenConsole.exe',
    name: 'OpenConsole.exe',
  ),
];

/// The architecture bestie installs the console host for.
const consoleHostArchitecture = 'x64';

/// The package that owns the installed binaries: the FFI package that opens
/// `conpty.dll`, matching how every other native library is placed.
const consoleHostAssetDir = 'packages/ffi/win32_dart/assets/native/windows';

/// Where the generated licence notice is written.
const consoleHostNoticeFile = 'assets/third_party_licenses/OpenConsole.txt';
