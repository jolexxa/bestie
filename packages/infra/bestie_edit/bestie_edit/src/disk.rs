//! Writing a file safely, and how the operating system's refusals are named.
//!
//! A mutation holds the path's lock (see `lock`) from its first read to its
//! final rename, so only one writer at a time sees and replaces a file.

use std::fs;
use std::io::{self, ErrorKind, Write};
use std::path::{Path, PathBuf};
use std::process;

use crate::wire::Reply;

/// Why the program could not answer at all, as opposed to a [`Reply`].
#[derive(Debug)]
pub struct Failure(pub String);

/// The reply an I/O error earns: the two refusals the model can act on get
/// their own words, anything else is a failure to answer.
pub fn refused(error: io::Error, path: &Path) -> Result<Reply, Failure> {
    match error.kind() {
        ErrorKind::NotFound => Ok(Reply::PathMissing),
        ErrorKind::PermissionDenied => Ok(Reply::Denied),
        _ => Err(Failure(format!("{}: {error}", path.display()))),
    }
}

/// Writes next to the target and renames over it, so a reader never sees a
/// half-written file and a failure leaves the original untouched. The file
/// keeps [`permissions`] when given, else the platform's defaults.
pub fn write_atomically(
    path: &Path,
    contents: &str,
    permissions: Option<fs::Permissions>,
) -> io::Result<()> {
    let temp = sibling(path, &format!(".bestie-edit-{}", process::id()));
    let written = (|| {
        let mut file = fs::File::create(&temp)?;
        file.write_all(contents.as_bytes())?;
        file.sync_all()?;
        if let Some(permissions) = permissions {
            file.set_permissions(permissions)?;
        }
        drop(file);
        fs::rename(&temp, path)
    })();
    if written.is_err() {
        let _ = fs::remove_file(&temp);
    }
    written
}

/// The dotfile `.{name}{suffix}` in `path`'s directory, where a target's temp
/// file and lock file live.
pub fn sibling(path: &Path, suffix: &str) -> PathBuf {
    let directory = match path.parent() {
        Some(parent) if !parent.as_os_str().is_empty() => parent,
        _ => Path::new("."),
    };
    let name = path
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default();
    directory.join(format!(".{name}{suffix}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_sibling_is_a_dotfile_beside_the_target() {
        assert_eq!(
            sibling(Path::new("/work/notes.md"), ".lock"),
            Path::new("/work/.notes.md.lock")
        );
    }

    #[test]
    fn a_bare_name_gets_its_sibling_in_the_current_directory() {
        assert_eq!(
            sibling(Path::new("notes.md"), ".lock"),
            Path::new("./.notes.md.lock")
        );
    }
}
