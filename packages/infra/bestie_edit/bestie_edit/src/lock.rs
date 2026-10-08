//! One writer at a time per path: a lock file beside the target, held for the
//! whole mutation, so parallel edits of one file wait their turn instead of
//! overwriting each other.

use std::fs::{self, File, OpenOptions};
use std::io;
use std::path::{Path, PathBuf};

use same_file::Handle;

use crate::disk::sibling;

const SUFFIX: &str = ".bestie-edit.lock";

/// An exclusive hold on a path's lock. Dropping it removes the lock file and
/// releases the lock, in that order.
pub struct PathLock {
    file: File,
    path: PathBuf,
}

/// Takes the lock beside `target`, waiting for any current holder to finish.
pub fn hold(target: &Path) -> io::Result<PathLock> {
    let path = sibling(target, SUFFIX);
    loop {
        let file = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(&path)?;
        file.lock()?;
        // The holder that just released may have removed the file we opened,
        // in which case the name now belongs to a newer file whose lock we do
        // not hold, and we go again.
        let held = Handle::from_file(file.try_clone()?)?;
        if Handle::from_path(&path).is_ok_and(|current| current == held) {
            return Ok(PathLock { file, path });
        }
    }
}

impl Drop for PathLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
        let _ = self.file.unlock();
    }
}

#[cfg(test)]
mod tests {
    use std::sync::mpsc;
    use std::sync::{Arc, Mutex};
    use std::thread;
    use std::time::Duration;

    use super::*;
    use crate::scratch::ScratchFile;

    fn lock_path(file: &ScratchFile) -> PathBuf {
        sibling(&file.0, SUFFIX)
    }

    #[test]
    fn holding_makes_the_lock_file_and_releasing_removes_it() {
        let file = ScratchFile::with(b"x\n");
        let lock = hold(&file.0).unwrap();
        assert!(lock_path(&file).exists());
        drop(lock);
        assert!(!lock_path(&file).exists());
    }

    #[test]
    fn a_second_holder_waits_for_the_first_to_release() {
        let file = ScratchFile::with(b"x\n");
        let log = Arc::new(Mutex::new(Vec::new()));
        let (waiting, is_waiting) = mpsc::channel();

        let first = hold(&file.0).unwrap();
        let second = thread::spawn({
            let path = file.0.clone();
            let log = Arc::clone(&log);
            move || {
                waiting.send(()).unwrap();
                let _held = hold(&path).unwrap();
                log.lock().unwrap().push("second held");
            }
        });
        is_waiting.recv().unwrap();
        thread::sleep(Duration::from_millis(50));
        log.lock().unwrap().push("first released");
        drop(first);
        second.join().unwrap();

        assert_eq!(*log.lock().unwrap(), ["first released", "second held"]);
        assert!(!lock_path(&file).exists());
    }

    #[test]
    fn a_lock_file_left_behind_is_reused_and_cleaned_up() {
        let file = ScratchFile::with(b"x\n");
        fs::write(lock_path(&file), b"from a crashed holder").unwrap();
        let lock = hold(&file.0).unwrap();
        assert!(lock_path(&file).exists());
        drop(lock);
        assert!(!lock_path(&file).exists());
    }
}
