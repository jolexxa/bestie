/// A parsed unified diff (`git diff` style) — one or more files, each made
/// up of one or more hunks of typed lines.
class UnifiedDiff {
  /// Creates a diff from a list of file changes.
  const UnifiedDiff(this.files);

  /// Files described by the diff, in document order.
  final List<DiffFile> files;
}

/// One file's worth of changes inside a [UnifiedDiff].
class DiffFile {
  /// Creates a diff file entry.
  const DiffFile({
    required this.oldPath,
    required this.newPath,
    required this.hunks,
  });

  /// Path on the `---` side. `null` for added files (`/dev/null`).
  final String? oldPath;

  /// Path on the `+++` side. `null` for deleted files (`/dev/null`).
  final String? newPath;

  /// The display path to show in headers — prefers [newPath], falls back to
  /// [oldPath]. Returns `null` only if both are missing (malformed).
  String? get displayPath => newPath ?? oldPath;

  /// Hunks in document order.
  final List<DiffHunk> hunks;
}

/// One `@@ -oldStart,oldCount +newStart,newCount @@` block.
class DiffHunk {
  /// Creates a hunk with its anchor line numbers and body.
  const DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });

  /// First line number this hunk covers on the old side.
  final int oldStart;

  /// Number of lines this hunk spans on the old side.
  final int oldCount;

  /// First line number this hunk covers on the new side.
  final int newStart;

  /// Number of lines this hunk spans on the new side.
  final int newCount;

  /// The hunk's body lines in document order.
  final List<DiffLine> lines;
}

/// The role a single line plays inside a hunk.
enum DiffLineKind {
  /// Unchanged context line (` ` prefix).
  context,

  /// Line added in the new file (`+` prefix).
  addition,

  /// Line removed from the old file (`-` prefix).
  deletion,
}

/// A single line of a hunk, with line numbers resolved against the hunk
/// header's [DiffHunk.oldStart] / [DiffHunk.newStart].
class DiffLine {
  /// Creates a diff line.
  const DiffLine({
    required this.kind,
    required this.text,
    this.oldLineNumber,
    this.newLineNumber,
    this.noNewlineAtEof = false,
  });

  /// Whether this line is context, an addition, or a deletion.
  final DiffLineKind kind;

  /// Line content without the leading `+`/`-`/` ` marker and without the
  /// trailing newline.
  final String text;

  /// Line number on the old (`-`) side. `null` for pure additions.
  final int? oldLineNumber;

  /// Line number on the new (`+`) side. `null` for pure deletions.
  final int? newLineNumber;

  /// True if the original file lacked a trailing newline at this line. Set
  /// when the line is followed by the `\ No newline at end of file` marker.
  final bool noNewlineAtEof;
}

/// Parses git-style unified diffs into a [UnifiedDiff] structure.
///
/// Tolerates and ignores `diff --git`, `index`, `similarity index`, and other
/// git metadata lines. Accepts diffs with or without those headers — a bare
/// hunk (no file headers, just `@@ ... @@` and lines) parses into a single
/// file with `null` paths.
class UnifiedDiffParser {
  /// Parses [input] into a [UnifiedDiff]. Never throws — malformed input
  /// degrades to an empty result rather than failing.
  static UnifiedDiff parse(String input) {
    final files = <DiffFile>[];
    final lines = input.split('\n');

    String? oldPath;
    String? newPath;
    final hunks = <DiffHunk>[];

    int? oldCursor;
    int? newCursor;
    DiffHunk? currentHunk;
    var currentLines = <DiffLine>[];

    void closeHunk() {
      if (currentHunk == null) return;
      hunks.add(
        DiffHunk(
          oldStart: currentHunk!.oldStart,
          oldCount: currentHunk!.oldCount,
          newStart: currentHunk!.newStart,
          newCount: currentHunk!.newCount,
          lines: currentLines,
        ),
      );
      currentHunk = null;
      currentLines = <DiffLine>[];
      oldCursor = null;
      newCursor = null;
    }

    void closeFile() {
      closeHunk();
      if (oldPath == null && newPath == null && hunks.isEmpty) return;
      files.add(
        DiffFile(
          oldPath: oldPath,
          newPath: newPath,
          hunks: List.of(hunks),
        ),
      );
      oldPath = null;
      newPath = null;
      hunks.clear();
    }

    for (final line in lines) {
      if (line.startsWith('diff --git ')) {
        closeFile();
        continue;
      }
      if (line.startsWith('--- ')) {
        // Close any in-progress file. We get here either because the diff
        // lacks `diff --git` framing or because that framing has already been
        // consumed for the *previous* file — either way, a `---` after we've
        // already collected hunks (or paths) is the start of a new file.
        if (oldPath != null || newPath != null || hunks.isNotEmpty) {
          closeFile();
        } else {
          closeHunk();
        }
        oldPath = _extractPath(line.substring(4));
        continue;
      }
      if (line.startsWith('+++ ')) {
        closeHunk();
        newPath = _extractPath(line.substring(4));
        continue;
      }
      if (line.startsWith('@@')) {
        closeHunk();
        final header = _parseHunkHeader(line);
        if (header == null) continue;
        currentHunk = header;
        oldCursor = header.oldStart;
        newCursor = header.newStart;
        continue;
      }

      if (currentHunk == null) {
        // Pre-hunk noise (index lines, mode lines, blank lines) — ignore.
        continue;
      }

      if (line.startsWith(r'\ ')) {
        // `\ No newline at end of file` — annotate the previous line.
        if (currentLines.isNotEmpty) {
          final last = currentLines.removeLast();
          currentLines.add(
            DiffLine(
              kind: last.kind,
              text: last.text,
              oldLineNumber: last.oldLineNumber,
              newLineNumber: last.newLineNumber,
              noNewlineAtEof: true,
            ),
          );
        }
        continue;
      }

      if (line.isEmpty) {
        // Trailing blank line at end of input; treat as end-of-hunk if we
        // had nothing pending. Inside a hunk, a blank line is a context line
        // with an empty body — but only if we still have rows to consume per
        // the hunk header counts. Stay conservative: drop trailing blanks.
        continue;
      }

      final marker = line[0];
      final text = line.substring(1);
      switch (marker) {
        case ' ':
          currentLines.add(
            DiffLine(
              kind: DiffLineKind.context,
              text: text,
              oldLineNumber: oldCursor,
              newLineNumber: newCursor,
            ),
          );
          oldCursor = oldCursor! + 1;
          newCursor = newCursor! + 1;
        case '+':
          currentLines.add(
            DiffLine(
              kind: DiffLineKind.addition,
              text: text,
              newLineNumber: newCursor,
            ),
          );
          newCursor = newCursor! + 1;
        case '-':
          currentLines.add(
            DiffLine(
              kind: DiffLineKind.deletion,
              text: text,
              oldLineNumber: oldCursor,
            ),
          );
          oldCursor = oldCursor! + 1;
        default:
        // Unknown marker — ignore. (Could be a stray header line we didn't
        // recognize; skipping keeps the rest of the hunk usable.)
      }
    }

    closeFile();
    return UnifiedDiff(files);
  }

  /// Extracts a clean path from a `--- a/foo.dart\t...` or `+++ b/foo.dart`
  /// fragment. Strips the leading `a/` or `b/` prefix git adds, and any
  /// trailing tab-separated timestamp. Returns `null` for `/dev/null`.
  static String? _extractPath(String raw) {
    var path = raw;
    final tab = path.indexOf('\t');
    if (tab >= 0) path = path.substring(0, tab);
    path = path.trim();
    if (path == '/dev/null') return null;
    if (path.startsWith('a/') || path.startsWith('b/')) {
      return path.substring(2);
    }
    return path;
  }

  static final _hunkHeader = RegExp(
    r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',
  );

  /// Parses an `@@ -a,b +c,d @@` header. Returns `null` if the line doesn't
  /// match; counts default to `1` when omitted (per the unified diff spec for
  /// single-line hunks).
  static DiffHunk? _parseHunkHeader(String line) {
    final match = _hunkHeader.firstMatch(line);
    if (match == null) return null;
    return DiffHunk(
      oldStart: int.parse(match.group(1)!),
      oldCount: int.parse(match.group(2) ?? '1'),
      newStart: int.parse(match.group(3)!),
      newCount: int.parse(match.group(4) ?? '1'),
      lines: const [],
    );
  }
}
