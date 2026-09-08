//! Writing a file safely, and how the operating system's refusals are named.

use std::fs;
use std::io::{self, ErrorKind, Write};
use std::path::Path;
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
    let directory = match path.parent() {
        Some(parent) if !parent.as_os_str().is_empty() => parent,
        _ => Path::new("."),
    };
    let name = path
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default();
    let temp = directory.join(format!(".{name}.bestie-edit-{}", process::id()));
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
