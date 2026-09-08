import 'package:bestie/src/app/assets/app_assets.dart';
import 'package:test/test.dart';

void main() {
  test('shared assets ship on every platform manifest', () {
    for (final assets in [macOSAppAssets, linuxAppAssets]) {
      expect(assets.bundleAssets, containsAll(sharedAppAssets.all));
    }
    expect(windowsAppAssets.bundleAssets, containsAll(sharedAppAssets.all));
  });

  test('macOS ships the mach-o native libraries', () {
    expect(macOSAppAssets.curl.path, 'libcurl-impersonate.dylib');
    expect(macOSAppAssets.spawner.path, 'spawner');
  });

  test('Linux ships the elf native libraries', () {
    expect(linuxAppAssets.curl.path, 'libcurl-impersonate.so');
    expect(linuxAppAssets.spawner.path, 'spawner');
  });

  test('Windows ships the dll native libraries and console host', () {
    expect(windowsAppAssets.curl.path, 'libcurl-impersonate.dll');
    expect(windowsAppAssets.conptyLibrary.path, 'conpty.dll');
    expect(windowsAppAssets.consoleHostExecutable.path, 'OpenConsole.exe');
  });

  test('Windows bundles no POSIX-only spawner helper', () {
    expect(
      windowsAppAssets.bundleAssets.map((a) => a.path),
      isNot(contains('spawner')),
    );
  });
}
