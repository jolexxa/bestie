import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// `path  +lines`, the one line that sums a new file up.
String createdSummary(CreatedFileSection section) =>
    '${section.path}  +${section.lines}';

/// `path  +added −removed`, the one line that sums a change up.
String diffSummary(DiffSection section) =>
    '${section.path}  +${section.diff.added} −${section.diff.removed}';

/// [section] as unified-diff text, the shape a diff renderer reads.
String unifiedDiff(DiffSection section) => [
  '--- a/${section.path}',
  '+++ b/${section.path}',
  for (final hunk in section.diff.hunks) ...[
    _header(hunk),
    for (final line in hunk.lines) '${_sigil(line.kind)}${line.text}',
  ],
].join('\n');

String _header(DiffHunk hunk) =>
    '@@ -${hunk.oldStart},${hunk.oldCount} '
    '+${hunk.newStart},${hunk.newCount} @@';

String _sigil(DiffLineKind kind) => switch (kind) {
  DiffLineKind.added => '+',
  DiffLineKind.removed => '-',
  DiffLineKind.context => ' ',
};
