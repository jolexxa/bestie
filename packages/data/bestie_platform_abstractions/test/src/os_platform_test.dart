import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

const _server = ProgramCommand(executable: '/opt/bestie_server');

void main() {
  // Each variant fixes its own [OSKind] rather than taking one, so a platform
  // cannot be constructed claiming to be an operating system it isn't.
  group('a platform reports the operating system it is', () {
    test('macOS', () {
      final platform = MacOSPlatform(
        architecture: OSArchitecture.macosArm64,
        homeDir: '/Users/cow',
        tempDir: '/tmp',
        workingDirectory: '/work',
        bestieDir: '/Users/cow/.bestie',
        configFile: '/Users/cow/.bestie/bestie.json',
        conversationsDir: '/Users/cow/.bestie/conversations',
        curlLibraryPath: '/opt/libcurl.dylib',
        caCertPath: '/opt/cacert.pem',
        creditsPath: '/opt/CREDITS.md',
        serverExecutable: _server,
      );

      expect(platform.os, OSKind.macos);
      expect(platform.architecture, OSArchitecture.macosArm64);
      expect(platform.paths.shortenHome('/Users/cow/proj'), '~/proj');
    });

    test('Windows', () {
      final platform = WindowsPlatform(
        architecture: OSArchitecture.windowsX64,
        homeDir: r'C:\Users\cow',
        tempDir: r'C:\Users\cow\AppData\Local\Temp',
        workingDirectory: r'C:\work',
        bestieDir: r'C:\Users\cow\.bestie',
        configFile: r'C:\Users\cow\.bestie\bestie.json',
        conversationsDir: r'C:\Users\cow\.bestie\conversations',
        curlLibraryPath: r'C:\opt\libcurl.dll',
        caCertPath: r'C:\opt\cacert.pem',
        creditsPath: r'C:\opt\CREDITS.md',
        serverExecutable: _server,
      );

      expect(platform.os, OSKind.windows);
      expect(platform.architecture, OSArchitecture.windowsX64);
      expect(platform.paths.shortenHome(r'C:\Users\cow\proj'), r'~\proj');
    });

    test('Linux', () {
      final platform = LinuxPlatform(
        architecture: OSArchitecture.linuxX64,
        homeDir: '/home/cow',
        tempDir: '/tmp',
        workingDirectory: '/work',
        bestieDir: '/home/cow/.bestie',
        configFile: '/home/cow/.bestie/bestie.json',
        conversationsDir: '/home/cow/.bestie/conversations',
        curlLibraryPath: '/opt/libcurl.so',
        caCertPath: '/opt/cacert.pem',
        creditsPath: '/opt/CREDITS.md',
        serverExecutable: _server,
      );

      expect(platform.os, OSKind.linux);
      expect(platform.architecture, OSArchitecture.linuxX64);
      expect(platform.paths.shortenHome('/home/cow/proj'), '~/proj');
    });
  });

  test('a platform carries the resolved paths it was built with', () {
    final platform = LinuxPlatform(
      architecture: OSArchitecture.linuxX64,
      homeDir: '/home/cow',
      tempDir: '/tmp',
      workingDirectory: '/work',
      bestieDir: '/home/cow/.bestie',
      configFile: '/home/cow/.bestie/bestie.json',
      conversationsDir: '/home/cow/.bestie/conversations',
      curlLibraryPath: '/opt/libcurl.so',
      caCertPath: '/opt/cacert.pem',
      creditsPath: '/opt/CREDITS.md',
      serverExecutable: _server,
    );

    expect(platform.homeDir, '/home/cow');
    expect(platform.bestieDir, '/home/cow/.bestie');
    expect(platform.configFile, '/home/cow/.bestie/bestie.json');
    expect(platform.conversationsDir, '/home/cow/.bestie/conversations');
    expect(platform.sandboxesFile, '/home/cow/.bestie/sandboxes.json');
    expect(
      platform.modelCatalogCacheFile,
      '/home/cow/.bestie/cache/models_dev.json',
    );
    expect(platform.logsDir, '/home/cow/.bestie/logs');
    expect(platform.crashLogFile, '/home/cow/.bestie/logs/crash.log');
    expect(platform.nativeLogFile, '/home/cow/.bestie/logs/native.log');
    expect(platform.managedLogFile, '/home/cow/.bestie/logs/managed.log');
    expect(platform.curlLibraryPath, '/opt/libcurl.so');
    expect(platform.caCertPath, '/opt/cacert.pem');
    expect(platform.creditsPath, '/opt/CREDITS.md');
    expect(platform.serverExecutable, _server);
    expect(platform.modelsDir, '/home/cow/.bestie/models');
    expect(platform.runDir, '/home/cow/.bestie/run');
    expect(platform.inferenceLockFile, '/home/cow/.bestie/run/inference.lock');
    expect(platform.serverLogFile, '/home/cow/.bestie/logs/server.log');
  });
}
