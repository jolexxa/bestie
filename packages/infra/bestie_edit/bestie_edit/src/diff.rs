//! Line diffs between the file as it was and as it is now.

use similar::{ChangeTag, TextDiff};

use crate::wire::{DiffHunk, DiffLine, DiffLineKind, FileDiff};

/// Unchanged lines shown either side of a change.
const CONTEXT_LINES: usize = 3;

/// Lines a diff may carry before the rest is dropped; the counts stay whole.
pub const LINE_CAP: usize = 2000;

pub fn diff(old: &str, new: &str) -> FileDiff {
    let text = TextDiff::from_lines(old, new);
    let mut added = 0;
    let mut removed = 0;
    for change in text.iter_all_changes() {
        match change.tag() {
            ChangeTag::Insert => added += 1,
            ChangeTag::Delete => removed += 1,
            ChangeTag::Equal => {}
        }
    }

    let mut hunks = Vec::new();
    let mut carried = 0;
    let mut truncated = false;
    'groups: for group in text.grouped_ops(CONTEXT_LINES) {
        let (Some(first), Some(last)) = (group.first(), group.last()) else {
            continue;
        };
        let old_range = first.old_range().start..last.old_range().end;
        let new_range = first.new_range().start..last.new_range().end;
        let mut lines = Vec::new();
        for op in &group {
            for change in text.iter_changes(op) {
                if carried == LINE_CAP {
                    truncated = true;
                    hunks.push(hunk(&old_range, &new_range, lines));
                    break 'groups;
                }
                lines.push(DiffLine {
                    kind: kind(change.tag()),
                    text: without_newline(change.value()).to_owned(),
                });
                carried += 1;
            }
        }
        hunks.push(hunk(&old_range, &new_range, lines));
    }

    FileDiff {
        hunks,
        added,
        removed,
        truncated,
    }
}

fn hunk(
    old_range: &std::ops::Range<usize>,
    new_range: &std::ops::Range<usize>,
    lines: Vec<DiffLine>,
) -> DiffHunk {
    DiffHunk {
        old_start: old_range.start + 1,
        old_count: old_range.len(),
        new_start: new_range.start + 1,
        new_count: new_range.len(),
        lines,
    }
}

fn kind(tag: ChangeTag) -> DiffLineKind {
    match tag {
        ChangeTag::Equal => DiffLineKind::Context,
        ChangeTag::Insert => DiffLineKind::Added,
        ChangeTag::Delete => DiffLineKind::Removed,
    }
}

fn without_newline(line: &str) -> &str {
    line.strip_suffix("\r\n")
        .or_else(|| line.strip_suffix('\n'))
        .unwrap_or(line)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_changed_line_is_one_hunk_with_context() {
        let old = "a\nb\nc\nd\ne\nf\ng\n";
        let new = "a\nb\nc\nD\ne\nf\ng\n";
        let result = diff(old, new);
        assert_eq!(result.added, 1);
        assert_eq!(result.removed, 1);
        assert!(!result.truncated);
        assert_eq!(result.hunks.len(), 1);
        let hunk = &result.hunks[0];
        assert_eq!((hunk.old_start, hunk.old_count), (1, 7));
        assert_eq!((hunk.new_start, hunk.new_count), (1, 7));
        let kinds: Vec<_> = hunk.lines.iter().map(|line| line.kind).collect();
        assert_eq!(
            kinds,
            vec![
                DiffLineKind::Context,
                DiffLineKind::Context,
                DiffLineKind::Context,
                DiffLineKind::Removed,
                DiffLineKind::Added,
                DiffLineKind::Context,
                DiffLineKind::Context,
                DiffLineKind::Context,
            ]
        );
        assert_eq!(hunk.lines[3].text, "d");
        assert_eq!(hunk.lines[4].text, "D");
    }

    #[test]
    fn distant_changes_become_separate_hunks() {
        let old: String = (0..40).map(|i| format!("line {i}\n")).collect();
        let new = old
            .replace("line 2\n", "LINE 2\n")
            .replace("line 30\n", "LINE 30\n");
        let result = diff(&old, &new);
        assert_eq!(result.hunks.len(), 2);
        assert_eq!(result.hunks[1].old_start, 28);
    }

    #[test]
    fn crlf_lines_lose_their_endings() {
        let result = diff("a\r\nb\r\n", "a\r\nB\r\n");
        assert_eq!(result.hunks[0].lines[0].text, "a");
        assert_eq!(result.hunks[0].lines[1].text, "b");
        assert_eq!(result.hunks[0].lines[2].text, "B");
    }

    #[test]
    fn a_huge_change_is_truncated_but_counted() {
        let old = "x\n";
        let new: String = (0..(LINE_CAP + 50)).map(|i| format!("{i}\n")).collect();
        let result = diff(old, &new);
        assert!(result.truncated);
        assert_eq!(result.added, LINE_CAP + 50);
        assert_eq!(result.removed, 1);
        let carried: usize = result.hunks.iter().map(|hunk| hunk.lines.len()).sum();
        assert_eq!(carried, LINE_CAP);
    }
}
