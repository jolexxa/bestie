import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('resolving the home directory', () {
    test('prefers HOME', () {
      expect(
        resolveHomeDir(const {'HOME': '/home/cow', 'USERPROFILE': r'C:\cow'}),
        '/home/cow',
      );
    });

    test('falls back to USERPROFILE where HOME is not set', () {
      expect(resolveHomeDir(const {'USERPROFILE': r'C:\cow'}), r'C:\cow');
    });

    // An empty variable is the same as an unset one: joining paths onto it
    // would silently produce a relative path rooted at the process's cwd.
    test('treats an empty HOME as unset', () {
      expect(
        resolveHomeDir(const {'HOME': '', 'USERPROFILE': r'C:\cow'}),
        r'C:\cow',
      );
    });

    test('fails rather than guessing when neither is set', () {
      expect(
        () => resolveHomeDir(const {'USERPROFILE': ''}),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('resolving the POSIX temp directory', () {
    test('prefers TMPDIR, without the trailing slash macOS gives it', () {
      expect(
        resolvePosixTempDir(const {'TMPDIR': '/var/folders/ab/cd/T/'}),
        '/var/folders/ab/cd/T',
      );
    });

    test('falls back to /tmp where TMPDIR is not set or empty', () {
      expect(resolvePosixTempDir(const {}), '/tmp');
      expect(resolvePosixTempDir(const {'TMPDIR': ''}), '/tmp');
    });
  });

  group('resolving the Windows temp directory', () {
    const home = r'C:\Users\cow';

    test('prefers TMP over TEMP, like GetTempPath', () {
      expect(
        resolveWindowsTempDir(const {
          'TMP': r'D:\tmp\',
          'TEMP': r'C:\temp',
        }, homeDir: home),
        r'D:\tmp',
      );
      expect(
        resolveWindowsTempDir(const {'TEMP': r'C:\temp'}, homeDir: home),
        r'C:\temp',
      );
    });

    test('falls back to the local app data temp under home', () {
      expect(
        resolveWindowsTempDir(const {'TMP': ''}, homeDir: home),
        r'C:\Users\cow\AppData\Local\Temp',
      );
    });
  });

  group('the bestie directory layout', () {
    const home = '/home/cow';
    final bestieDir = bestieDirFor(home, p.posix);

    test('lives in a dot directory under the home directory', () {
      expect(bestieDir, '/home/cow/.bestie');
    });

    test('holds config and conversations side by side', () {
      expect(configFileFor(bestieDir, p.posix), '$bestieDir/bestie.json');
      expect(
        conversationsDirFor(bestieDir, p.posix),
        '$bestieDir/conversations',
      );
      expect(
        modelCatalogCacheFileFor(bestieDir, p.posix),
        '$bestieDir/cache/models_dev.json',
      );
    });

    test('gathers all logs in one directory', () {
      final logsDir = logsDirFor(bestieDir, p.posix);

      expect(logsDir, '$bestieDir/logs');
      expect(nativeLogFileFor(bestieDir, p.posix), '$logsDir/native.log');
      expect(managedLogFileFor(bestieDir, p.posix), '$logsDir/managed.log');
      expect(crashLogFileFor(bestieDir, p.posix), '$logsDir/crash.log');
    });

    test('a windows layout joins with backslashes', () {
      final winDir = bestieDirFor(r'C:\Users\cow', p.windows);

      expect(winDir, r'C:\Users\cow\.bestie');
      expect(
        configFileFor(winDir, p.windows),
        r'C:\Users\cow\.bestie\bestie.json',
      );
    });
  });
}
