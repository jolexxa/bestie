import 'package:path/path.dart' as p;
import 'package:sandbox/sandbox.dart';
import 'package:test/test.dart';

void main() {
  group('unlistedAncestorsOf', () {
    test('walks a Windows root up to its drive, top-down', () {
      expect(
        unlistedAncestorsOf(
          roots: [r'C:\Users\cow'],
          context: p.windows,
        ),
        [r'C:\', r'C:\Users'],
      );
    });

    test('walks a POSIX root up to /', () {
      expect(
        unlistedAncestorsOf(roots: ['/home/cow/src'], context: p.posix),
        ['/', '/home', '/home/cow'],
      );
    });

    test('names each shared ancestor once, in the order first reached', () {
      expect(
        unlistedAncestorsOf(
          roots: [r'C:\Users\cow', r'C:\Users\cow\Desktop\project', r'D:\code'],
          context: p.windows,
        ),
        [r'C:\', r'C:\Users', r'D:\'],
      );
    });

    test('skips an ancestor another root already covers', () {
      expect(
        unlistedAncestorsOf(
          roots: [r'C:\Users', r'C:\Users\cow\Desktop\project'],
          context: p.windows,
        ),
        [r'C:\'],
      );
    });

    test('skips ancestors under a system root', () {
      expect(
        unlistedAncestorsOf(
          roots: [r'C:\Program Files\bestie\bin'],
          context: p.windows,
          systemRoots: [r'C:\Program Files'],
        ),
        [r'C:\'],
      );
    });

    test('matches Windows paths regardless of case', () {
      expect(
        unlistedAncestorsOf(
          roots: [r'c:\users', r'C:\Users\cow'],
          context: p.windows,
        ),
        [r'c:\'],
      );
    });

    test('a drive root has no ancestors', () {
      expect(unlistedAncestorsOf(roots: [r'C:\'], context: p.windows), isEmpty);
    });
  });
}
