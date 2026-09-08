//! The JSON spoken on stdin and stdout. Field names are camelCase so the Dart
//! side maps them without renaming.

use serde::{Deserialize, Serialize};

/// What the program is asked to do to one file.
#[derive(Debug, Deserialize)]
#[serde(tag = "action", rename_all = "camelCase")]
pub enum Request {
    /// One exact-string replacement in an existing file.
    #[serde(rename_all = "camelCase")]
    Edit {
        path: String,
        old: String,
        new: String,
        #[serde(default)]
        replace_all: bool,
    },
    /// A new file with the given contents.
    Create { path: String, contents: String },
}

/// What became of the request.
#[derive(Debug, Serialize, PartialEq, Eq)]
#[serde(tag = "outcome", rename_all = "camelCase")]
pub enum Reply {
    #[serde(rename_all = "camelCase")]
    Succeeded {
        replacements: usize,
        snippet: String,
        diff: FileDiff,
    },
    Created,
    TargetMissing,
    Ambiguous {
        occurrences: usize,
    },
    NoChange,
    PathMissing,
    PathExists,
    IsDirectory,
    Denied,
    NotText,
}

/// The change, as unified-diff hunks.
#[derive(Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct FileDiff {
    pub hunks: Vec<DiffHunk>,
    pub added: usize,
    pub removed: usize,
    pub truncated: bool,
}

/// One run of changed lines with its context, addressed 1-based in both
/// versions of the file.
#[derive(Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct DiffHunk {
    pub old_start: usize,
    pub old_count: usize,
    pub new_start: usize,
    pub new_count: usize,
    pub lines: Vec<DiffLine>,
}

#[derive(Debug, Serialize, PartialEq, Eq)]
pub struct DiffLine {
    pub kind: DiffLineKind,
    pub text: String,
}

#[derive(Debug, Serialize, PartialEq, Eq, Clone, Copy)]
#[serde(rename_all = "lowercase")]
pub enum DiffLineKind {
    Context,
    Added,
    Removed,
}
