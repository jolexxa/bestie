import 'package:bestie_chat_view/src/view/details/change_text.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

const _hunk = DiffHunk(
  oldStart: 10,
  oldCount: 3,
  newStart: 10,
  newCount: 3,
  lines: [
    DiffLine(kind: DiffLineKind.context, text: 'before'),
    DiffLine(kind: DiffLineKind.removed, text: 'old line'),
    DiffLine(kind: DiffLineKind.added, text: 'new line'),
    DiffLine(kind: DiffLineKind.context, text: 'after'),
  ],
);

void main() {
  test('sums a new file up as its path and line count', () {
    expect(
      createdSummary(
        const CreatedFileSection('a\nb\n', path: 'lib/new.dart', lines: 2),
      ),
      'lib/new.dart  +2',
    );
  });

  test('sums a change up as its path and line counts', () {
    expect(
      diffSummary(
        const DiffSection(
          FileDiff(hunks: [_hunk], added: 12, removed: 3),
          path: 'lib/a.dart',
        ),
      ),
      'lib/a.dart  +12 −3',
    );
  });

  test('writes every hunk out as unified diff text', () {
    expect(
      unifiedDiff(
        const DiffSection(
          FileDiff(hunks: [_hunk, _hunk], added: 2, removed: 2),
          path: 'lib/a.dart',
        ),
      ),
      [
        '--- a/lib/a.dart',
        '+++ b/lib/a.dart',
        '@@ -10,3 +10,3 @@',
        ' before',
        '-old line',
        '+new line',
        ' after',
        '@@ -10,3 +10,3 @@',
        ' before',
        '-old line',
        '+new line',
        ' after',
      ].join('\n'),
    );
  });
}
