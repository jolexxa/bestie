import 'package:markdown_highlighted/src/internal/unified_diff.dart';
import 'package:test/test.dart';

void main() {
  group('UnifiedDiffParser.parse', () {
    test('parses a single file with one hunk', () {
      const diff = '''
diff --git a/foo.dart b/foo.dart
--- a/foo.dart
+++ b/foo.dart
@@ -1,3 +1,3 @@
 ctx
-old
+new
''';
      final parsed = UnifiedDiffParser.parse(diff);
      expect(parsed.files, hasLength(1));
      final file = parsed.files.single;
      expect(file.oldPath, 'foo.dart');
      expect(file.newPath, 'foo.dart');
      expect(file.displayPath, 'foo.dart');
      expect(file.hunks, hasLength(1));
      final hunk = file.hunks.single;
      expect(hunk.oldStart, 1);
      expect(hunk.oldCount, 3);
      expect(hunk.newStart, 1);
      expect(hunk.newCount, 3);
      expect(hunk.lines.map((l) => l.kind), [
        DiffLineKind.context,
        DiffLineKind.deletion,
        DiffLineKind.addition,
      ]);
    });

    test('assigns line numbers to context/+/- lines', () {
      const diff = '''
--- a/x
+++ b/x
@@ -10,3 +20,3 @@
 a
-b
+c
''';
      final file = UnifiedDiffParser.parse(diff).files.single;
      final lines = file.hunks.single.lines;
      expect(lines[0].oldLineNumber, 10);
      expect(lines[0].newLineNumber, 20);
      expect(lines[1].oldLineNumber, 11);
      expect(lines[1].newLineNumber, isNull);
      expect(lines[2].oldLineNumber, isNull);
      expect(lines[2].newLineNumber, 21);
    });

    test('parses multiple hunks in one file', () {
      const diff = '''
--- a/x
+++ b/x
@@ -1,1 +1,1 @@
-a
+b
@@ -10,1 +10,1 @@
-c
+d
''';
      final file = UnifiedDiffParser.parse(diff).files.single;
      expect(file.hunks, hasLength(2));
      expect(file.hunks[0].oldStart, 1);
      expect(file.hunks[1].oldStart, 10);
    });

    test('parses multiple files in one diff', () {
      const diff = '''
diff --git a/one b/one
--- a/one
+++ b/one
@@ -1,1 +1,1 @@
-a
+b
diff --git a/two b/two
--- a/two
+++ b/two
@@ -1,1 +1,1 @@
-x
+y
''';
      final parsed = UnifiedDiffParser.parse(diff);
      expect(parsed.files, hasLength(2));
      expect(parsed.files[0].displayPath, 'one');
      expect(parsed.files[1].displayPath, 'two');
    });

    test('handles /dev/null for added and deleted files', () {
      const added = '''
--- /dev/null
+++ b/new.txt
@@ -0,0 +1,1 @@
+hello
''';
      final addedFile = UnifiedDiffParser.parse(added).files.single;
      expect(addedFile.oldPath, isNull);
      expect(addedFile.newPath, 'new.txt');
      expect(addedFile.displayPath, 'new.txt');

      const deleted = '''
--- a/gone.txt
+++ /dev/null
@@ -1,1 +0,0 @@
-bye
''';
      final delFile = UnifiedDiffParser.parse(deleted).files.single;
      expect(delFile.oldPath, 'gone.txt');
      expect(delFile.newPath, isNull);
      expect(delFile.displayPath, 'gone.txt');
    });

    test(r'annotates `\ No newline at end of file` on the previous line', () {
      const diff =
          '--- a/x\n+++ b/x\n@@ -1,1 +1,1 @@\n-a\n'
          r'\ No newline at end of file'
          '\n+b\n';
      final lines = UnifiedDiffParser.parse(
        diff,
      ).files.single.hunks.single.lines;
      expect(lines[0].noNewlineAtEof, isTrue);
      expect(lines[1].noNewlineAtEof, isFalse);
    });

    test(
      'accepts hunk headers without explicit counts (single-line hunks)',
      () {
        const diff = '''
--- a/x
+++ b/x
@@ -1 +1 @@
-a
+b
''';
        final hunk = UnifiedDiffParser.parse(diff).files.single.hunks.single;
        expect(hunk.oldCount, 1);
        expect(hunk.newCount, 1);
      },
    );

    test('handles bare hunks with no file headers', () {
      const diff = '''
@@ -1,1 +1,1 @@
-a
+b
''';
      final parsed = UnifiedDiffParser.parse(diff);
      expect(parsed.files, hasLength(1));
      expect(parsed.files.single.oldPath, isNull);
      expect(parsed.files.single.newPath, isNull);
      expect(parsed.files.single.displayPath, isNull);
    });

    test('strips trailing tab-separated timestamps from --- / +++ lines', () {
      const diff =
          '--- foo.txt\t2026-01-01 00:00:00\n'
          '+++ foo.txt\t2026-01-02 00:00:00\n'
          '@@ -1,1 +1,1 @@\n-a\n+b\n';
      final file = UnifiedDiffParser.parse(diff).files.single;
      expect(file.oldPath, 'foo.txt');
      expect(file.newPath, 'foo.txt');
    });

    test('ignores pre-hunk noise (index, mode lines)', () {
      const diff = '''
diff --git a/x b/x
index abc123..def456 100644
--- a/x
+++ b/x
@@ -1,1 +1,1 @@
-a
+b
''';
      final file = UnifiedDiffParser.parse(diff).files.single;
      expect(file.hunks.single.lines, hasLength(2));
    });

    test('returns an empty diff for empty input', () {
      expect(UnifiedDiffParser.parse(''), isA<UnifiedDiff>());
      expect(UnifiedDiffParser.parse('').files, isEmpty);
    });

    test('ignores unknown line markers inside a hunk', () {
      const diff = '''
--- a/x
+++ b/x
@@ -1,1 +1,1 @@
?weird-marker
-a
+b
''';
      final lines = UnifiedDiffParser.parse(
        diff,
      ).files.single.hunks.single.lines;
      // The `?` line is skipped; only the -/+ remain.
      expect(lines, hasLength(2));
    });

    test('ignores malformed hunk headers', () {
      const diff = '''
--- a/x
+++ b/x
@@ this is not a real header @@
something
@@ -1,1 +1,1 @@
-a
+b
''';
      final file = UnifiedDiffParser.parse(diff).files.single;
      expect(file.hunks, hasLength(1));
    });

    test(r'handles `\` annotation when no previous line exists', () {
      // Edge: parser shouldn't crash if the annotation is the first body line.
      const diff =
          '--- a/x\n+++ b/x\n@@ -1,1 +1,1 @@\n'
          r'\ No newline at end of file'
          '\n+a\n';
      final lines = UnifiedDiffParser.parse(
        diff,
      ).files.single.hunks.single.lines;
      expect(lines, hasLength(1));
      expect(lines.single.kind, DiffLineKind.addition);
    });

    test('preserves path when no a/ or b/ prefix is present', () {
      const diff = '''
--- foo.txt
+++ foo.txt
@@ -1,1 +1,1 @@
-a
+b
''';
      final file = UnifiedDiffParser.parse(diff).files.single;
      expect(file.oldPath, 'foo.txt');
      expect(file.newPath, 'foo.txt');
    });
  });
}
