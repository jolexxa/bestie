//! The macOS backend: lower a [`Policy`] to an SBPL profile and hand it to
//! the kernel via `sandbox_init`. Confinement is irreversible and inherited
//! across `execvp`.

use std::collections::BTreeSet;
use std::ffi::{c_char, CStr, CString};
use std::path::Path;
use std::ptr;

use crate::policy::{Access, Policy};
use crate::ConfineError;

// The Seatbelt entry points.
extern "C" {
    fn sandbox_init(profile: *const c_char, flags: u64, errorbuf: *mut *mut c_char) -> i32;
    fn sandbox_free_error(errorbuf: *mut c_char);
}

/// Owns the error buffer `sandbox_init` may allocate, freeing it on drop.
struct SandboxError(*mut c_char);

impl SandboxError {
    fn message(&self) -> Option<String> {
        (!self.0.is_null()).then(|| {
            unsafe { CStr::from_ptr(self.0) }
                .to_string_lossy()
                .into_owned()
        })
    }
}

impl Drop for SandboxError {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { sandbox_free_error(self.0) };
        }
    }
}

/// Apply [`policy`] to the current process. Must run single-threaded (the
/// spawner's post-fork, pre-exec child), where allocation is safe.
pub fn apply(policy: &Policy) -> Result<(), ConfineError> {
    let profile = generate_profile(policy)?;
    let profile = CString::new(profile).map_err(|_| ConfineError::BadPath)?;

    let mut error = SandboxError(ptr::null_mut());
    let rc = unsafe { sandbox_init(profile.as_ptr(), 0, &mut error.0) };
    if rc != 0 {
        return Err(ConfineError::ApplyFailed(
            error
                .message()
                .unwrap_or_else(|| format!("sandbox_init returned {rc}")),
        ));
    }
    Ok(())
}

fn generate_profile(policy: &Policy) -> Result<String, ConfineError> {
    let mut p = String::from(BASE_PROFILE);

    push_network(&mut p, policy);

    // Metadata on every ancestor so path resolution can traverse to a grant.
    for dir in ancestors(policy) {
        writeln_rule(&mut p, "file-read-metadata", &literal(&dir)?);
    }

    for grant in &policy.grants {
        let subpath = subpath(&grant.path)?;
        writeln_rule(&mut p, "file-read*", &subpath);
        writeln_rule(&mut p, "file-map-executable", &subpath);
        writeln_rule(&mut p, "file-ioctl", &subpath);
        if grant.access == Access::ReadWrite {
            writeln_rule(&mut p, "file-write*", &subpath);
        }
    }

    // Denies land last so they win under Seatbelt's last-rule-wins semantics.
    // Paths are concrete.
    for deny in &policy.denies {
        let filter = subpath(&deny.path)?;
        p.push_str(&format!("(deny file-read* {filter})\n"));
    }

    Ok(p)
}

fn push_network(p: &mut String, policy: &Policy) {
    use crate::policy::Network;
    match policy.network {
        Network::All => p.push_str(
            "(allow system-socket)\n\
             (allow network-outbound)\n\
             (allow network-inbound)\n\
             (allow network-bind)\n",
        ),
        Network::Local => p.push_str(LOCAL_NETWORK),
        // The base profile already denies by default; state it for the reader.
        Network::None => p.push_str("(deny network*)\n"),
    }
}

/// The `local` tier: loopback TCP only. Seatbelt cannot port- or address-filter
/// bind/inbound, so those are allowed wholesale and the outbound filter is what
/// confines reach to loopback.
const LOCAL_NETWORK: &str = "\
(allow system-socket (socket-domain AF_INET) (socket-type SOCK_STREAM))\n\
(allow system-socket (socket-domain AF_INET6) (socket-type SOCK_STREAM))\n\
(allow network-outbound (remote tcp \"localhost:*\"))\n\
(allow network-bind)\n\
(allow network-inbound)\n\
(allow system-socket (socket-domain AF_UNIX) (socket-type SOCK_STREAM))\n\
(allow network-outbound (path \"/private/var/run/mDNSResponder\"))\n\
(allow network-outbound (path \"/var/run/mDNSResponder\"))\n";

/// Unique ancestor directories of every grant and deny, nearest root first,
/// excluding `/` (already granted metadata by the base profile).
fn ancestors(policy: &Policy) -> BTreeSet<String> {
    let mut set = BTreeSet::new();
    let paths = policy
        .grants
        .iter()
        .map(|g| g.path.as_str())
        .chain(policy.denies.iter().map(|d| d.path.as_str()));
    for path in paths {
        let mut cur = Path::new(path);
        while let Some(parent) = cur.parent() {
            match parent.to_str() {
                Some("/") | Some("") | None => break,
                Some(dir) => {
                    set.insert(dir.to_owned());
                    cur = parent;
                }
            }
        }
    }
    set
}

fn writeln_rule(p: &mut String, op: &str, filter: &str) {
    p.push_str(&format!("(allow {op} {filter})\n"));
}

fn literal(path: &str) -> Result<String, ConfineError> {
    Ok(format!("(literal \"{}\")", escape(path)?))
}

fn subpath(path: &str) -> Result<String, ConfineError> {
    Ok(format!("(subpath \"{}\")", escape(path)?))
}

/// Escape a path for a double-quoted SBPL string, refusing control chars.
fn escape(path: &str) -> Result<String, ConfineError> {
    reject_control_chars(path)?;
    let mut out = String::with_capacity(path.len());
    for c in path.chars() {
        match c {
            '\\' | '"' => {
                out.push('\\');
                out.push(c);
            }
            _ => out.push(c),
        }
    }
    Ok(out)
}

fn reject_control_chars(path: &str) -> Result<(), ConfineError> {
    if path.chars().any(|c| c.is_control()) {
        return Err(ConfineError::BadPath);
    }
    Ok(())
}

/// The static base: deny-all, then the minimum a shell and its children need
/// to exec, resolve libraries, drive a tty, and open the device nodes every
/// program assumes (`/dev/null`, the terminal); keychain daemons stay denied.
/// Device rules require a character device so a regular file swapped in at
/// the same path gains nothing.
const BASE_PROFILE: &str = "(version 1)\n\
(deny default)\n\
(allow process-exec*)\n\
(allow process-fork)\n\
(allow process-info* (target self))\n\
(allow process-info* (target same-sandbox))\n\
(allow sysctl-read)\n\
(allow system-info)\n\
(allow system-fsctl)\n\
(allow mach-lookup)\n\
(deny mach-lookup (global-name \"com.apple.SecurityServer\"))\n\
(deny mach-lookup (global-name \"com.apple.securityd\"))\n\
(deny mach-lookup (global-name \"com.apple.security.keychaind\"))\n\
(deny mach-lookup (global-name \"com.apple.secd\"))\n\
(deny mach-lookup (global-name \"com.apple.security.agent\"))\n\
(allow mach-per-user-lookup)\n\
(allow mach-task-name)\n\
(deny mach-priv*)\n\
(allow ipc-posix-shm-read-data)\n\
(allow ipc-posix-shm-write-data)\n\
(allow ipc-posix-shm-write-create)\n\
(allow signal (target self))\n\
(allow signal (target same-sandbox))\n\
(allow file-read* (literal \"/\"))\n\
(allow pseudo-tty)\n\
(allow file-ioctl (regex #\"^/dev/pty[a-z][0-9a-f]+$\"))\n\
(allow file-read-data file-write-data file-ioctl (require-all (literal \"/dev/null\") (vnode-type CHARACTER-DEVICE)))\n\
(allow file-read* file-write* file-ioctl (require-all (literal \"/dev/tty\") (vnode-type CHARACTER-DEVICE)))\n\
(allow file-read* file-write* file-ioctl (require-all (literal \"/dev/ptmx\") (vnode-type CHARACTER-DEVICE)))\n\
(allow file-read* file-write* file-ioctl (require-all (regex #\"^/dev/ttys[0-9]+$\") (vnode-type CHARACTER-DEVICE)))\n";

#[cfg(test)]
mod tests {
    use super::*;
    use crate::policy::{Deny, Grant, Network};

    fn profile(policy: &Policy) -> String {
        generate_profile(policy).unwrap()
    }

    #[test]
    fn readwrite_grant_emits_read_and_write_subpaths() {
        let p = profile(&Policy {
            grants: vec![Grant {
                path: "/w".into(),
                access: Access::ReadWrite,
            }],
            ..Policy::default()
        });
        assert!(p.contains("(allow file-read* (subpath \"/w\"))"));
        assert!(p.contains("(allow file-write* (subpath \"/w\"))"));
    }

    #[test]
    fn read_grant_never_emits_write() {
        let p = profile(&Policy {
            grants: vec![Grant {
                path: "/usr".into(),
                access: Access::Read,
            }],
            ..Policy::default()
        });
        assert!(p.contains("(allow file-read* (subpath \"/usr\"))"));
        assert!(!p.contains("(allow file-write* (subpath \"/usr\"))"));
    }

    #[test]
    fn plain_deny_is_subpath_and_lands_after_allows() {
        let p = profile(&Policy {
            grants: vec![Grant {
                path: "/w".into(),
                access: Access::ReadWrite,
            }],
            denies: vec![Deny {
                path: "/w/.git".into(),
            }],
            ..Policy::default()
        });
        let allow_at = p.find("(allow file-read* (subpath \"/w\"))").unwrap();
        let deny_at = p.find("(deny file-read* (subpath \"/w/.git\"))").unwrap();
        assert!(deny_at > allow_at, "deny must win under last-rule-wins");
    }

    #[test]
    fn ancestors_get_metadata_reads() {
        let p = profile(&Policy {
            grants: vec![Grant {
                path: "/a/b/c".into(),
                access: Access::Read,
            }],
            ..Policy::default()
        });
        assert!(p.contains("(allow file-read-metadata (literal \"/a\"))"));
        assert!(p.contains("(allow file-read-metadata (literal \"/a/b\"))"));
        assert!(!p.contains("(allow file-read-metadata (literal \"/a/b/c\"))"));
    }

    #[test]
    fn all_tier_allows_network_unfiltered() {
        let p = profile(&Policy {
            network: Network::All,
            ..Policy::default()
        });
        assert!(p.contains("(allow network-outbound)\n"));
        assert!(p.contains("(allow network-inbound)\n"));
        assert!(!p.contains("(deny network*)"));
    }

    #[test]
    fn none_tier_denies_network() {
        let p = profile(&Policy {
            network: Network::None,
            ..Policy::default()
        });
        assert!(p.contains("(deny network*)"));
        assert!(!p.contains("(allow network-outbound"));
    }

    #[test]
    fn local_tier_allows_loopback_and_mdns() {
        let p = profile(&Policy {
            network: Network::Local,
            ..Policy::default()
        });
        // Loopback TCP: outbound filtered to localhost, bind/inbound wholesale.
        assert!(p.contains("(allow network-outbound (remote tcp \"localhost:*\"))"));
        assert!(p.contains("(allow network-bind)"));
        assert!(p.contains("(allow network-inbound)"));
        assert!(
            p.contains("(allow system-socket (socket-domain AF_INET) (socket-type SOCK_STREAM))")
        );
        assert!(
            p.contains("(allow system-socket (socket-domain AF_INET6) (socket-type SOCK_STREAM))")
        );
        // DNS via mDNSResponder so `localhost` resolves.
        assert!(
            p.contains("(allow system-socket (socket-domain AF_UNIX) (socket-type SOCK_STREAM))")
        );
        assert!(p.contains("(allow network-outbound (path \"/private/var/run/mDNSResponder\"))"));
        assert!(p.contains("(allow network-outbound (path \"/var/run/mDNSResponder\"))"));
        // Local is not a blanket allow, and not a blanket deny.
        assert!(!p.contains("(deny network*)"));
        assert!(!p.contains("(allow network-outbound)\n"));
    }

    #[test]
    fn base_profile_opens_the_null_device_for_writing() {
        let p = profile(&Policy::default());
        assert!(p.contains(
            "(allow file-read-data file-write-data file-ioctl \
             (require-all (literal \"/dev/null\") (vnode-type CHARACTER-DEVICE)))"
        ));
    }

    #[test]
    fn base_profile_opens_the_terminal_devices_for_writing() {
        let p = profile(&Policy::default());
        for device in [
            "(literal \"/dev/tty\")",
            "(literal \"/dev/ptmx\")",
            "(regex #\"^/dev/ttys[0-9]+$\")",
        ] {
            assert!(
                p.contains(&format!(
                    "(allow file-read* file-write* file-ioctl \
                     (require-all {device} (vnode-type CHARACTER-DEVICE)))"
                )),
                "missing write rule for {device}"
            );
        }
    }

    #[test]
    fn control_chars_in_path_are_refused() {
        assert!(matches!(
            generate_profile(&Policy {
                grants: vec![Grant {
                    path: "/w\n/etc".into(),
                    access: Access::Read,
                }],
                ..Policy::default()
            }),
            Err(ConfineError::BadPath)
        ));
    }

    #[test]
    fn quotes_in_path_are_escaped() {
        let p = profile(&Policy {
            grants: vec![Grant {
                path: "/w/a\"b".into(),
                access: Access::Read,
            }],
            ..Policy::default()
        });
        assert!(p.contains("(subpath \"/w/a\\\"b\")"));
    }
}
