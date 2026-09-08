import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:test/test.dart';

void main() {
  group('isLanguageSupported', () {
    test('returns true for a known language', () {
      expect(isLanguageSupported('dart'), isTrue);
      expect(isLanguageSupported('rust'), isTrue);
    });

    test('returns false for unknown ids', () {
      expect(isLanguageSupported('not-a-language'), isFalse);
    });
  });

  group('resolveLanguageId', () {
    test('null hint returns plaintext', () {
      expect(resolveLanguageId(null), 'plaintext');
    });

    test('lower-cases the hint before lookup', () {
      expect(resolveLanguageId('Dart'), 'dart');
    });

    test('unknown hint falls back to plaintext', () {
      expect(resolveLanguageId('fictional-lang'), 'plaintext');
    });

    test('known hint returns the hint unchanged', () {
      expect(resolveLanguageId('rust'), 'rust');
    });
  });

  group('inferLanguageFromPath', () {
    test('returns null for a null path', () {
      expect(inferLanguageFromPath(null), isNull);
    });

    test('returns null for a path without a usable hint', () {
      expect(inferLanguageFromPath('nope'), isNull);
    });

    test('detects language from extension', () {
      expect(inferLanguageFromPath('lib/foo.dart'), 'dart');
      expect(inferLanguageFromPath('src/main.rs'), 'rust');
      expect(inferLanguageFromPath('README.md'), 'markdown');
    });

    test('is case-insensitive', () {
      expect(inferLanguageFromPath('Foo.DART'), 'dart');
    });

    test('detects whole-filename matches before extension fallback', () {
      expect(inferLanguageFromPath('Dockerfile'), 'dockerfile');
      expect(inferLanguageFromPath('path/to/Makefile'), 'makefile');
    });

    test('returns null for an unknown extension', () {
      expect(inferLanguageFromPath('thing.xyz'), isNull);
    });
  });

  group('registerAllLanguages', () {
    test('is idempotent', () {
      registerAllLanguages();
      registerAllLanguages();
      // No throw means success — the flag prevents double-registration.
      expect(isLanguageSupported('dart'), isTrue);
    });
  });
}
