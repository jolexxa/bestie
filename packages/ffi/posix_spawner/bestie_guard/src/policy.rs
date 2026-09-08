//! The platform-agnostic confinement request — what every backend enforces.

/// Filesystem access a grant confers. `Read` implies execute; there is no
/// separate execute bit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Access {
    /// Read (and execute).
    Read,
    /// Read, execute, and write.
    ReadWrite,
    /// List the directory only — its entries are visible but contents are
    /// not readable.
    ListDir,
}

/// A path subtree the confined process may access at [`Access`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Grant {
    /// The absolute path granted, recursively.
    pub path: String,
    /// The access level.
    pub access: Access,
}

/// A read the confined process is denied, even inside a granted subtree.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Deny {
    /// The absolute path whose reads are refused.
    pub path: String,
}

/// The network posture. Each backend translates the tier into its own rules.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Network {
    /// Unrestricted network access (the default tier).
    #[default]
    All,
    /// Loopback only.
    Local,
    /// No network.
    None,
}

/// A lowered confinement request: the decoded wire program a backend applies.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Policy {
    /// Path subtrees the process may access.
    pub grants: Vec<Grant>,
    /// Reads refused even within granted subtrees.
    pub denies: Vec<Deny>,
    /// The network posture.
    pub network: Network,
}
