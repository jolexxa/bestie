import 'package:path/path.dart' as p;
import 'package:path_plus/path_plus.dart';
import 'package:test/test.dart';

void main() {
  group('UserPaths', () {
    final posix = UserPaths(homeDir: '/home/cow', context: p.posix);
    final windows = UserPaths(homeDir: r'C:\Users\cow', context: p.windows);

    group('expandHome', () {
      test('replaces a leading ~ with the home directory', () {
        expect(posix.expandHome('~'), '/home/cow');
        expect(posix.expandHome('~/models'), '/home/cow/models');
        expect(posix.expandHome(r'~\models'), '/home/cow/models');
        expect(windows.expandHome('~'), r'C:\Users\cow');
        expect(windows.expandHome('~/models'), r'C:\Users\cow\models');
        expect(windows.expandHome(r'~\models'), r'C:\Users\cow\models');
      });

      test('leaves every other path alone', () {
        expect(posix.expandHome('~cow/models'), '~cow/models');
        expect(posix.expandHome('/opt/models'), '/opt/models');
        expect(posix.expandHome('models'), 'models');
        expect(posix.expandHome(''), '');
        expect(windows.expandHome(r'D:\models'), r'D:\models');
      });
    });

    group('shortenHome', () {
      test('writes the home directory and what is under it as ~', () {
        expect(posix.shortenHome('/home/cow'), '~');
        expect(posix.shortenHome('/home/cow/models/a.gguf'), '~/models/a.gguf');
        expect(windows.shortenHome(r'C:\Users\cow'), '~');
        expect(
          windows.shortenHome(r'C:\Users\cow\models\a.gguf'),
          r'~\models\a.gguf',
        );
      });

      test('matches the home directory the way the OS does', () {
        expect(windows.shortenHome(r'c:\users\COW\models'), r'~\models');
        expect(posix.shortenHome('/home/COW/models'), '/home/COW/models');
      });

      test('leaves paths outside the home directory alone', () {
        expect(posix.shortenHome('/opt/models'), '/opt/models');
        expect(posix.shortenHome('/home/cowboy/models'), '/home/cowboy/models');
        expect(windows.shortenHome(r'D:\models'), r'D:\models');
      });
    });

    test('underHome joins a /-written relative path onto home', () {
      expect(posix.underHome('.config/gh'), '/home/cow/.config/gh');
      expect(
        windows.underHome('AppData/Roaming/gcloud'),
        r'C:\Users\cow\AppData\Roaming\gcloud',
      );
      expect(windows.underHome('.ssh'), r'C:\Users\cow\.ssh');
    });

    test('isAbsolute and normalize follow the OS', () {
      expect(posix.isAbsolute('/opt'), isTrue);
      expect(posix.isAbsolute('opt'), isFalse);
      expect(windows.isAbsolute(r'C:\opt'), isTrue);
      expect(windows.isAbsolute('opt'), isFalse);
      expect(posix.normalize('/opt/models/../gguf/'), '/opt/gguf');
      expect(windows.normalize(r'C:\opt\models\..\gguf'), r'C:\opt\gguf');
    });

    group('resolve', () {
      test('expands ~ and normalizes', () {
        expect(posix.resolve('~', from: '/work'), '/home/cow');
        expect(posix.resolve('~/a/../b', from: '/work'), '/home/cow/b');
        expect(windows.resolve('~/a', from: r'C:\work'), r'C:\Users\cow\a');
      });

      test('keeps an absolute path and takes a relative one from [from]', () {
        expect(posix.resolve('/opt/models/', from: '/work'), '/opt/models');
        expect(posix.resolve('build', from: '/work'), '/work/build');
        expect(posix.resolve('../other', from: '/work/app'), '/work/other');
        expect(windows.resolve('build', from: r'C:\work'), r'C:\work\build');
      });
    });

    test('covers a path equal to or under the root', () {
      expect(posix.covers('/work', '/work'), isTrue);
      expect(posix.covers('/work', '/work/src/a.dart'), isTrue);
      expect(posix.covers('/work', '/workspace'), isFalse);
      expect(posix.covers('/work', '/other'), isFalse);
      expect(windows.covers(r'C:\work', r'c:\WORK\src'), isTrue);
      expect(windows.covers(r'C:\work', r'D:\work'), isFalse);
    });

    test('isFilesystemRoot knows the whole filesystem', () {
      expect(posix.isFilesystemRoot('/'), isTrue);
      expect(posix.isFilesystemRoot('/home'), isFalse);
      expect(windows.isFilesystemRoot(r'C:\'), isTrue);
      expect(windows.isFilesystemRoot(r'C:\Users'), isFalse);
    });

    test('isHome knows the home directory the way the OS does', () {
      expect(posix.isHome('/home/cow'), isTrue);
      expect(posix.isHome('/home/cow/models'), isFalse);
      expect(posix.isHome('/home/COW'), isFalse);
      expect(windows.isHome(r'c:\users\COW'), isTrue);
    });
  });
}
