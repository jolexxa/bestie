//! Decoder for the NUL-delimited wire program the Dart sandbox layer hands the child.
//!
//! Layout: `magic \0 tier \0 (verb \0 path \0)*`, verbs `r` / `rw` / `l` / `d`.
//! `l` is the Landlock-only list-directory grant; `d` is the macOS-only native
//! deny.

use crate::policy::{Access, Deny, Grant, Network, Policy};

/// The wire magic and version. A mismatch fails closed.
const MAGIC: &[u8] = b"sandbox/1";

/// Why a wire program could not be decoded.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WireError {
    /// The leading field was not the expected magic/version.
    BadMagic,
    /// The network tier field was not one of `all` / `local` / `none`.
    UnknownNetworkTier,
    /// A record verb was not one of `r` / `rw` / `l` / `d`.
    UnknownVerb,
    /// A verb was present without its path.
    Truncated,
    /// A path field was not valid UTF-8.
    NonUtf8,
}

/// Decode [`Policy`] from a wire program, failing closed on any anomaly.
pub fn parse(bytes: &[u8]) -> Result<Policy, WireError> {
    let mut fields = bytes.split(|&b| b == 0);

    if fields.next() != Some(MAGIC) {
        return Err(WireError::BadMagic);
    }
    let network = match fields.next() {
        Some(tier) => parse_network(tier)?,
        None => return Err(WireError::Truncated),
    };

    let mut policy = Policy {
        network,
        ..Policy::default()
    };
    loop {
        let verb = match fields.next() {
            // The final field is empty (every record ends in a NUL), and the
            // grant list can be empty — both terminate the walk.
            None | Some([]) => break,
            Some(verb) => verb,
        };
        let path = match fields.next() {
            Some(path) if !path.is_empty() => {
                std::str::from_utf8(path).map_err(|_| WireError::NonUtf8)?
            }
            _ => return Err(WireError::Truncated),
        };
        match verb {
            b"r" => policy.grants.push(Grant {
                path: path.to_owned(),
                access: Access::Read,
            }),
            b"rw" => policy.grants.push(Grant {
                path: path.to_owned(),
                access: Access::ReadWrite,
            }),
            b"l" => policy.grants.push(Grant {
                path: path.to_owned(),
                access: Access::ListDir,
            }),
            b"d" => policy.denies.push(Deny {
                path: path.to_owned(),
            }),
            _ => return Err(WireError::UnknownVerb),
        }
    }
    Ok(policy)
}

fn parse_network(tier: &[u8]) -> Result<Network, WireError> {
    match tier {
        b"all" => Ok(Network::All),
        b"local" => Ok(Network::Local),
        b"none" => Ok(Network::None),
        _ => Err(WireError::UnknownNetworkTier),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn wire(fields: &[&[u8]]) -> Vec<u8> {
        let mut out = Vec::new();
        for f in fields {
            out.extend_from_slice(f);
            out.push(0);
        }
        out
    }

    #[test]
    fn decodes_grants_and_denies() {
        let bytes = wire(&[
            b"sandbox/1",
            b"all",
            b"rw",
            b"/w",
            b"r",
            b"/usr",
            b"d",
            b"/w/.git",
        ]);
        let policy = parse(&bytes).unwrap();
        assert_eq!(policy.network, Network::All);
        assert_eq!(
            policy.grants,
            vec![
                Grant {
                    path: "/w".into(),
                    access: Access::ReadWrite
                },
                Grant {
                    path: "/usr".into(),
                    access: Access::Read
                },
            ]
        );
        assert_eq!(
            policy.denies,
            vec![Deny {
                path: "/w/.git".into()
            }]
        );
    }

    #[test]
    fn decodes_list_dir_grant() {
        let bytes = wire(&[b"sandbox/1", b"all", b"l", b"/home/joanna"]);
        let policy = parse(&bytes).unwrap();
        assert_eq!(
            policy.grants,
            vec![Grant {
                path: "/home/joanna".into(),
                access: Access::ListDir
            }]
        );
        assert!(policy.denies.is_empty());
    }

    #[test]
    fn empty_grant_list_is_valid() {
        let policy = parse(&wire(&[b"sandbox/1", b"none"])).unwrap();
        assert_eq!(policy.network, Network::None);
        assert!(policy.grants.is_empty());
        assert!(policy.denies.is_empty());
    }

    #[test]
    fn wrong_magic_fails_closed() {
        assert_eq!(
            parse(&wire(&[b"sandbox/2", b"all"])),
            Err(WireError::BadMagic)
        );
        assert_eq!(parse(b"garbage"), Err(WireError::BadMagic));
    }

    #[test]
    fn unknown_tier_and_verb_fail_closed() {
        assert_eq!(
            parse(&wire(&[b"sandbox/1", b"lan"])),
            Err(WireError::UnknownNetworkTier)
        );
        assert_eq!(
            parse(&wire(&[b"sandbox/1", b"all", b"x", b"/w"])),
            Err(WireError::UnknownVerb)
        );
    }

    #[test]
    fn verb_without_path_is_truncated() {
        assert_eq!(
            parse(&wire(&[b"sandbox/1", b"all", b"r"])),
            Err(WireError::Truncated)
        );
    }
}
