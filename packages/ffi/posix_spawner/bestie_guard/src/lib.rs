//! bestie's process-confinement backend.
//!
//! A thin, capability-shaped adapter over the platform sandbox primitives —
//! Seatbelt (`sandbox_init`) on macOS, Landlock on Linux (later slice). The
//! caller hands over the NUL-delimited wire program the Dart sandbox layer
//! lowered; this crate decodes it into a [`Policy`] and jails the current
//! process.
//!
//! Confinement is irreversible and inherited across `execvp`. [`confine`] must
//! run single-threaded — the spawner's post-fork, pre-exec child — where
//! allocation is safe. Every failure is fail-closed: the caller must refuse to
//! run the child unconfined.

mod policy;
mod wire;

pub use policy::{Access, Deny, Grant, Network, Policy};
pub use wire::WireError;

#[cfg(target_os = "macos")]
#[path = "seatbelt.rs"]
mod backend;

#[cfg(target_os = "linux")]
#[path = "landlock.rs"]
mod backend;

#[cfg(not(any(target_os = "macos", target_os = "linux")))]
mod backend {
    use crate::{ConfineError, Policy};

    pub fn apply(_policy: &Policy) -> Result<(), ConfineError> {
        Err(ConfineError::UnsupportedPlatform)
    }
}

/// Why a confinement request could not be honoured.
#[derive(Debug)]
pub enum ConfineError {
    /// The wire program could not be decoded.
    Wire(WireError),
    /// No sandbox backend exists for this platform.
    UnsupportedPlatform,
    /// A path held control characters or an interior NUL.
    BadPath,
    /// The kernel refused to apply the profile.
    ApplyFailed(String),
}

impl std::fmt::Display for ConfineError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ConfineError::Wire(e) => write!(f, "malformed confine program: {e:?}"),
            ConfineError::UnsupportedPlatform => write!(f, "no sandbox backend for this platform"),
            ConfineError::BadPath => write!(f, "path contains control characters"),
            ConfineError::ApplyFailed(msg) => write!(f, "sandbox apply failed: {msg}"),
        }
    }
}

impl std::error::Error for ConfineError {}

impl From<WireError> for ConfineError {
    fn from(e: WireError) -> Self {
        ConfineError::Wire(e)
    }
}

/// Decode [`program`] and confine the current process to it.
pub fn confine(program: &[u8]) -> Result<(), ConfineError> {
    let policy = wire::parse(program)?;
    backend::apply(&policy)
}
