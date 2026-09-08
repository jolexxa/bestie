//! The replacement itself: read, match, write atomically, describe.

use std::fs;
use std::path::Path;

use crate::diff::diff;
use crate::disk::{refused, write_atomically, Failure};
use crate::wire::Reply;

/// Numbered lines shown either side of the edited region.
const SNIPPET_CONTEXT: usize = 4;

pub fn edit(path: &str, old: &str, new: &str, replace_all: bool) -> Result<Reply, Failure> {
    let path = Path::new(path);
    let metadata = match fs::metadata(path) {
        Ok(metadata) => metadata,
        Err(error) => return refused(error, path),
    };
    if metadata.is_dir() {
        return Ok(Reply::IsDirectory);
    }
    let bytes = match fs::read(path) {
        Ok(bytes) => bytes,
        Err(error) => return refused(error, path),
    };
    let Ok(original) = String::from_utf8(bytes) else {
        return Ok(Reply::NotText);
    };

    let (old, new) = with_file_line_endings(&original, old, new);
    let occurrences = original.matches(old.as_str()).count();
    if occurrences == 0 {
        return Ok(Reply::TargetMissing);
    }
    if occurrences > 1 && !replace_all {
        return Ok(Reply::Ambiguous { occurrences });
    }
    let edited = if replace_all {
        original.replace(&old, &new)
    } else {
        original.replacen(&old, &new, 1)
    };
    if edited == original {
        return Ok(Reply::NoChange);
    }

    if let Err(error) = write_atomically(path, &edited, Some(metadata.permissions())) {
        return refused(error, path);
    }

    let first = original.find(&old).unwrap_or(0);
    Ok(Reply::Succeeded {
        replacements: if replace_all { occurrences } else { 1 },
        snippet: snippet(&edited, first, &new),
        diff: diff(&original, &edited),
    })
}

/// A CRLF file is edited with CRLF strings, even when the request arrived
/// with bare LF, so the file's endings survive the edit.
fn with_file_line_endings(original: &str, old: &str, new: &str) -> (String, String) {
    if original.contains("\r\n") && !old.contains('\r') {
        (old.replace('\n', "\r\n"), new.replace('\n', "\r\n"))
    } else {
        (old.to_owned(), new.to_owned())
    }
}

/// The edited region of [`edited`] with a few lines either side, numbered
/// the way `cat -n` numbers them.
fn snippet(edited: &str, at: usize, new: &str) -> String {
    let first_line = edited[..at].matches('\n').count();
    let last_line = first_line + new.matches('\n').count();
    let start = first_line.saturating_sub(SNIPPET_CONTEXT);
    let end = last_line + SNIPPET_CONTEXT;
    edited
        .lines()
        .enumerate()
        .skip(start)
        .take(end - start + 1)
        .map(|(index, line)| format!("{:>6}\t{line}", index + 1))
        .collect::<Vec<_>>()
        .join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scratch::{ScratchDir, ScratchFile};
    use crate::wire::{DiffLineKind, Reply};

    #[test]
    fn replaces_a_unique_target_and_describes_it() {
        let file = ScratchFile::with(b"one\ntwo\nthree\n");
        let reply = edit(&file.path(), "two", "2", false).unwrap();
        let Reply::Succeeded {
            replacements,
            snippet,
            diff,
        } = reply
        else {
            panic!("expected success, got {reply:?}");
        };
        assert_eq!(replacements, 1);
        assert_eq!(file.read(), b"one\n2\nthree\n");
        assert_eq!(snippet, "     1\tone\n     2\t2\n     3\tthree");
        assert_eq!((diff.added, diff.removed), (1, 1));
        assert_eq!(diff.hunks[0].lines[1].kind, DiffLineKind::Removed);
    }

    #[test]
    fn a_missing_target_changes_nothing() {
        let file = ScratchFile::with(b"one\n");
        assert_eq!(
            edit(&file.path(), "zero", "0", false).unwrap(),
            Reply::TargetMissing
        );
        assert_eq!(file.read(), b"one\n");
    }

    #[test]
    fn a_repeated_target_is_ambiguous_unless_replacing_all() {
        let file = ScratchFile::with(b"a a a\n");
        assert_eq!(
            edit(&file.path(), "a", "b", false).unwrap(),
            Reply::Ambiguous { occurrences: 3 }
        );
        let reply = edit(&file.path(), "a", "b", true).unwrap();
        assert!(matches!(
            reply,
            Reply::Succeeded {
                replacements: 3,
                ..
            }
        ));
        assert_eq!(file.read(), b"b b b\n");
    }

    #[test]
    fn an_identical_replacement_is_no_change() {
        let file = ScratchFile::with(b"same\n");
        assert_eq!(
            edit(&file.path(), "same", "same", false).unwrap(),
            Reply::NoChange
        );
    }

    #[test]
    fn a_missing_path_is_reported() {
        let dir = ScratchDir::new();
        assert_eq!(
            edit(&dir.join("does-not-exist"), "a", "b", false).unwrap(),
            Reply::PathMissing
        );
    }

    #[test]
    fn a_directory_is_reported() {
        let dir = ScratchDir::new();
        assert_eq!(
            edit(&dir.join(""), "a", "b", false).unwrap(),
            Reply::IsDirectory
        );
    }

    #[test]
    fn binary_content_is_not_text() {
        let file = ScratchFile::with(&[0xff, 0xfe, 0x00, b'a']);
        assert_eq!(edit(&file.path(), "a", "b", false).unwrap(), Reply::NotText);
    }

    #[test]
    fn crlf_files_keep_their_endings() {
        let file = ScratchFile::with(b"one\r\ntwo\r\nthree\r\n");
        let reply = edit(&file.path(), "two\nthree", "2\n3", false).unwrap();
        assert!(matches!(reply, Reply::Succeeded { .. }));
        assert_eq!(file.read(), b"one\r\n2\r\n3\r\n");
    }

    #[test]
    fn multibyte_text_is_replaced_on_character_boundaries() {
        let file = ScratchFile::with("héllo wörld\n".as_bytes());
        let reply = edit(&file.path(), "wörld", "世界", false).unwrap();
        let Reply::Succeeded { snippet, .. } = reply else {
            panic!("expected success, got {reply:?}");
        };
        assert_eq!(file.read(), "héllo 世界\n".as_bytes());
        assert_eq!(snippet, "     1\théllo 世界");
    }

    #[test]
    fn the_snippet_surrounds_the_edit() {
        let contents: String = (1..=20).map(|i| format!("line {i}\n")).collect();
        let file = ScratchFile::with(contents.as_bytes());
        let reply = edit(&file.path(), "line 10\n", "ten\nand a half\n", false).unwrap();
        let Reply::Succeeded { snippet, .. } = reply else {
            panic!("expected success, got {reply:?}");
        };
        let lines: Vec<_> = snippet.lines().collect();
        assert_eq!(lines.first().unwrap().trim_start(), "6\tline 6");
        assert_eq!(lines.last().unwrap().trim_start(), "16\tline 15");
        assert_eq!(lines.len(), 11);
    }

    #[cfg(unix)]
    #[test]
    fn permissions_survive_the_rewrite() {
        use std::os::unix::fs::PermissionsExt;
        let file = ScratchFile::with(b"#!/bin/sh\necho hi\n");
        fs::set_permissions(&file.0, fs::Permissions::from_mode(0o755)).unwrap();
        edit(&file.path(), "hi", "bye", false).unwrap();
        let mode = fs::metadata(&file.0).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o755);
    }

    #[cfg(unix)]
    #[test]
    fn an_unreadable_file_is_denied() {
        use std::os::unix::fs::PermissionsExt;
        if unsafe { libc_geteuid() } == 0 {
            return;
        }
        let file = ScratchFile::with(b"secret\n");
        fs::set_permissions(&file.0, fs::Permissions::from_mode(0o000)).unwrap();
        assert_eq!(
            edit(&file.path(), "secret", "public", false).unwrap(),
            Reply::Denied
        );
        fs::set_permissions(&file.0, fs::Permissions::from_mode(0o644)).unwrap();
    }

    #[cfg(unix)]
    extern "C" {
        #[link_name = "geteuid"]
        fn libc_geteuid() -> u32;
    }
}
