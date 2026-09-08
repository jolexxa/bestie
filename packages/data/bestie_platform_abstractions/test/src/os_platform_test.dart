import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

void main() {
  // Each variant fixes its own [OSKind] rather than taking one, so a platform
  // cannot be constructed claiming to be an operating system it isn't.
  group('a platform reports the operating system it is', () {
    test('macOS', () {
      const platform = MacOSPlatform(
        architecture: OSArchitecture.macosArm64,
        homeDir: '/Users/cow',
        tempDir: '/tmp',
        bestieDir: '/Users/cow/.bestie',
        configFile: '/Users/cow/.bestie/bestie.json',
        conversationsDir: '/Users/cow/.bestie/conversations',
        curlLibraryPath: '/opt/libcurl.dylib',
        caCertPath: '/opt/cacert.pem',
        creditsPath: '/opt/CREDITS.md',
      );

      expect(platform.os, OSKind.macos);
      expect(platform.architecture, OSArchitecture.macosArm64);
    });

    test('Windows', () {
      const platform = WindowsPlatform(
        architecture: OSArchitecture.windowsX64,
        homeDir: r'C:\Users\cow',
        tempDir: r'C:\Users\cow\AppData\Local\Temp',
        bestieDir: r'C:\Users\cow\.bestie',
        configFile: r'C:\Users\cow\.bestie\bestie.json',
        conversationsDir: r'C:\Users\cow\.bestie\conversations',
        curlLibraryPath: r'C:\opt\libcurl.dll',
        caCertPath: r'C:\opt\cacert.pem',
        creditsPath: r'C:\opt\CREDITS.md',
      );

      expect(platform.os, OSKind.windows);
      expect(platform.architecture, OSArchitecture.windowsX64);
    });

    test('Linux', () {
      const platform = LinuxPlatform(
        architecture: OSArchitecture.linuxX64,
        homeDir: '/home/cow',
        tempDir: '/tmp',
        bestieDir: '/home/cow/.bestie',
        configFile: '/home/cow/.bestie/bestie.json',
        conversationsDir: '/home/cow/.bestie/conversations',
        curlLibraryPath: '/opt/libcurl.so',
        caCertPath: '/opt/cacert.pem',
        creditsPath: '/opt/CREDITS.md',
      );

      expect(platform.os, OSKind.linux);
      expect(platform.architecture, OSArchitecture.linuxX64);
    });
  });

  test('a platform carries the resolved paths it was built with', () {
    const platform = LinuxPlatform(
      architecture: OSArchitecture.linuxX64,
      homeDir: '/home/cow',
      tempDir: '/tmp',
      bestieDir: '/home/cow/.bestie',
      configFile: '/home/cow/.bestie/bestie.json',
      conversationsDir: '/home/cow/.bestie/conversations',
      curlLibraryPath: '/opt/libcurl.so',
      caCertPath: '/opt/cacert.pem',
      creditsPath: '/opt/CREDITS.md',
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
  });
}
