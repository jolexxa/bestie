import 'package:sandbox/src/lowering/glob.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('isGlob', () {
    test('detects metacharacters', () {
      expect(isGlob('/a/*.env'), isTrue);
      expect(isGlob('/a/b?'), isTrue);
      expect(isGlob('/a/[abc]'), isTrue);
    });

    test('is false for a plain path', () {
      expect(isGlob('/home/joanna/.ssh'), isFalse);
    });
  });

  group('splitGlob', () {
    test('splits at the first glob segment', () {
      final split = splitGlob('/home/joanna/*/secrets');
      expect(split.base, '/home/joanna');
      expect(split.tail, '*/secrets');
    });

    test('a plain path is all base', () {
      final split = splitGlob('/home/joanna/.ssh');
      expect(split.base, '/home/joanna/.ssh');
      expect(split.tail, isEmpty);
    });

    test('a leading glob leaves root as base', () {
      final split = splitGlob('**/.env');
      expect(split.base, '/');
      expect(split.tail, '**/.env');
    });
  });

  group('GlobExpander', () {
    final globs = GlobExpander(
      memFs(
        dirs: {
          '/home': ['/home/a.env', '/home/b.txt', '/home/sub'],
          '/home/sub': ['/home/sub/c.env'],
        },
      ),
    );

    test('matches a single level with *', () {
      final matches = globs.expand(base: '/home', tail: '*.env');
      expect(matches, ['/home/a.env']);
    });

    test('matches across depth with **', () {
      final matches = globs.expand(base: '/home', tail: '**/*.env');
      expect(matches, containsAll(['/home/a.env', '/home/sub/c.env']));
    });

    test('? matches exactly one character', () {
      final single = GlobExpander(
        memFs(
          dirs: {
            '/d': ['/d/ab.txt', '/d/abc.txt'],
          },
        ),
      );
      final matches = single.expand(base: '/d', tail: 'a?.txt');
      expect(matches, ['/d/ab.txt']);
    });

    test('enumerates every match without truncating', () {
      final many = GlobExpander(
        memFs(
          dirs: {
            '/d': ['/d/1.env', '/d/2.env', '/d/3.env'],
          },
        ),
      );
      final matches = many.expand(base: '/d', tail: '*.env');
      expect(matches, containsAll(['/d/1.env', '/d/2.env', '/d/3.env']));
    });

    test('a missing directory yields nothing', () {
      final matches = globs.expand(base: '/nope', tail: '*.env');
      expect(matches, isEmpty);
    });

    test('recurses through a matched directory for a multi-segment tail', () {
      final matches = globs.expand(base: '/home', tail: '*/c.env');
      expect(matches, ['/home/sub/c.env']);
    });

    test('a trailing ** matches the directory itself and all beneath it', () {
      final matches = globs.expand(base: '/home', tail: '**');
      expect(matches, containsAll(['/home', '/home/sub', '/home/sub/c.env']));
    });

    test('a character class segment matches any listed character', () {
      final classed = GlobExpander(
        memFs(
          dirs: {
            '/d': ['/d/a.txt', '/d/b.txt', '/d/c.txt'],
          },
        ),
      );
      final matches = classed.expand(base: '/d', tail: '[ab].txt');
      expect(matches, containsAll(['/d/a.txt', '/d/b.txt']));
      expect(matches, isNot(contains('/d/c.txt')));
    });
  });
}
