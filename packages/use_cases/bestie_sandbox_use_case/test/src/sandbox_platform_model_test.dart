import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:test/test.dart';

const _server = ProgramCommand(executable: '/opt/server');

void main() {
  final linux = LinuxPlatform(
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
  final windows = WindowsPlatform(
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

  group('SandboxPlatformModel', () {
    test("denies the secrets under home in the platform's own style", () {
      expect(
        SandboxPlatformModel.posix.deniedReadsFor(linux.paths),
        containsAll(['/home/cow/.ssh', '/home/cow/.config/gh']),
      );
      expect(
        SandboxPlatformModel.windows.deniedReadsFor(windows.paths),
        containsAll([
          r'C:\Users\cow\.bestie\bestie.json',
          r'C:\Users\cow\AppData\Roaming\gcloud',
        ]),
      );
    });

    test('grants home and temp only when the model includes them', () {
      expect(SandboxPlatformModel.posix.homeReadRoots(linux.paths), [
        '/home/cow',
      ]);
      expect(SandboxPlatformModel.posix.tempWriteRoots('/tmp'), ['/tmp']);
      expect(SandboxPlatformModel.windows.homeReadRoots(windows.paths), [
        r'C:\Users\cow',
      ]);
      expect(SandboxPlatformModel.windows.tempWriteRoots(r'C:\T'), isEmpty);
    });
  });
}
