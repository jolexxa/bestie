//! Throwaway files and directories for tests, gone when dropped.

use std::fs;
use std::path::PathBuf;
use std::process;
use std::sync::atomic::{AtomicUsize, Ordering};

static COUNTER: AtomicUsize = AtomicUsize::new(0);

fn unique(kind: &str) -> PathBuf {
    let unique = COUNTER.fetch_add(1, Ordering::SeqCst);
    std::env::temp_dir().join(format!("bestie_edit-{kind}-{}-{unique}", process::id()))
}

pub struct ScratchFile(pub PathBuf);

impl ScratchFile {
    pub fn with(contents: &[u8]) -> ScratchFile {
        let path = unique("file").with_extension("txt");
        fs::write(&path, contents).unwrap();
        ScratchFile(path)
    }

    pub fn path(&self) -> String {
        self.0.to_string_lossy().into_owned()
    }

    pub fn read(&self) -> Vec<u8> {
        fs::read(&self.0).unwrap()
    }
}

impl Drop for ScratchFile {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.0);
    }
}

pub struct ScratchDir(pub PathBuf);

impl ScratchDir {
    pub fn new() -> ScratchDir {
        let path = unique("dir");
        fs::create_dir_all(&path).unwrap();
        ScratchDir(path)
    }

    pub fn join(&self, relative: &str) -> String {
        self.0.join(relative).to_string_lossy().into_owned()
    }
}

impl Drop for ScratchDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
