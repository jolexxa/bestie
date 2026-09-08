import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

const _caCert = AppAsset(path: 'cacert.pem', missingMessage: 'no cert');
const _credits = AppAsset(path: 'CREDITS.md', missingMessage: 'no credits');
const _shellBin = AppAsset(path: 'shell/bin', missingMessage: 'no shell');

const _shared = SharedAppAssets(
  caCert: _caCert,
  credits: _credits,
  shellBin: _shellBin,
);

void main() {
  test('SharedAppAssets.all lists every shared asset', () {
    expect(_shared.all, [_caCert, _credits, _shellBin]);
  });

  test('PosixAppAssets.bundleAssets composes natives with shared assets', () {
    const curl = AppAsset(path: 'libcurl', missingMessage: 'no curl');
    const spawner = AppAsset(path: 'spawner', missingMessage: 'no spawner');
    const editor = AppAsset(path: 'bestie_edit', missingMessage: 'no editor');

    const assets = PosixAppAssets(
      curl: curl,
      spawner: spawner,
      editor: editor,
      shared: _shared,
    );

    expect(assets.bundleAssets, [curl, spawner, editor, ..._shared.all]);
  });

  test('WindowsAppAssets.bundleAssets composes natives with shared assets', () {
    const curl = AppAsset(path: 'curl.dll', missingMessage: 'no curl');
    const conpty = AppAsset(path: 'conpty.dll', missingMessage: 'no conpty');
    const console = AppAsset(
      path: 'OpenConsole.exe',
      missingMessage: 'no host',
    );

    const editor = AppAsset(
      path: 'bestie_edit.exe',
      missingMessage: 'no editor',
    );

    const assets = WindowsAppAssets(
      curl: curl,
      conptyLibrary: conpty,
      consoleHostExecutable: console,
      editor: editor,
      shared: _shared,
    );

    expect(assets.bundleAssets, [
      curl,
      conpty,
      console,
      editor,
      ..._shared.all,
    ]);
  });
}
