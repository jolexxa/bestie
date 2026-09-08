//! Bringing a new file into being, parents and all.

use std::fs;
use std::io::{self, ErrorKind};
use std::path::Path;

use crate::disk::{refused, write_atomically, Failure};
use crate::wire::Reply;

pub fn create(path: &str, contents: &str) -> Result<Reply, Failure> {
    let path = Path::new(path);
    if fs::symlink_metadata(path).is_ok() {
        return Ok(Reply::PathExists);
    }
    if let Some(parent) = path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
    {
        if let Err(error) = make_parents(parent) {
            return refused(error, path);
        }
    }
    match write_atomically(path, contents, None) {
        Ok(()) => Ok(Reply::Created),
        // The parents were just made, so a not-found here is a component in
        // the way (Windows phrases a file-as-parent this way), not a missing
        // target.
        Err(error) if error.kind() == ErrorKind::NotFound => {
            Err(Failure(format!("{}: {error}", path.display())))
        }
        Err(error) => refused(error, path),
    }
}

/// A parent that is already there is left alone, however the operating
/// system phrases that: a confined process is told "exists" about a
/// directory it may not even look at, and the write that follows is what
/// decides whether the file may be made.
fn make_parents(parent: &Path) -> io::Result<()> {
    match fs::create_dir_all(parent) {
        Err(error) if error.kind() != ErrorKind::AlreadyExists => Err(error),
        _ => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scratch::{ScratchDir, ScratchFile};

    #[test]
    fn writes_the_contents_exactly_making_parents_on_the_way() {
        let dir = ScratchDir::new();
        let path = dir.join("a/b/hello.txt");

        assert_eq!(create(&path, "one\r\ntwo\n").unwrap(), Reply::Created);

        assert_eq!(fs::read(&path).unwrap(), b"one\r\ntwo\n");
    }

    #[test]
    fn an_empty_file_is_still_a_file() {
        let dir = ScratchDir::new();
        let path = dir.join("empty");

        assert_eq!(create(&path, "").unwrap(), Reply::Created);

        assert_eq!(fs::read(&path).unwrap(), b"");
    }

    #[test]
    fn a_parent_that_is_a_file_cannot_be_answered() {
        let file = ScratchFile::with(b"in the way\n");

        let answered = create(&format!("{}/child.txt", file.path()), "x");

        assert!(answered.is_err());
        assert_eq!(file.read(), b"in the way\n");
    }

    #[test]
    fn refuses_to_replace_an_existing_file() {
        let file = ScratchFile::with(b"keep\n");

        assert_eq!(create(&file.path(), "lost").unwrap(), Reply::PathExists);

        assert_eq!(file.read(), b"keep\n");
    }

    #[test]
    fn refuses_a_path_that_is_a_directory() {
        let dir = ScratchDir::new();

        assert_eq!(create(&dir.join(""), "lost").unwrap(), Reply::PathExists);
    }

    #[cfg(unix)]
    #[test]
    fn an_unwritable_parent_is_denied() {
        use std::os::unix::fs::PermissionsExt;
        if unsafe { libc_geteuid() } == 0 {
            return;
        }
        let dir = ScratchDir::new();
        fs::set_permissions(&dir.0, fs::Permissions::from_mode(0o500)).unwrap();

        let reply = create(&dir.join("nope.txt"), "x").unwrap();

        fs::set_permissions(&dir.0, fs::Permissions::from_mode(0o700)).unwrap();
        assert_eq!(reply, Reply::Denied);
    }

    #[cfg(unix)]
    extern "C" {
        #[link_name = "geteuid"]
        fn libc_geteuid() -> u32;
    }
}
