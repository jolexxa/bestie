//! The Linux backend: confine the current process with Landlock (filesystem)
//! and, for the confining network tiers, a seccomp-BPF filter (`none`) or a
//! user+network namespace (`local`). Confinement is irreversible and inherited
//! across `execvp`.
//!
//! Ordering matters: network setup writes to procfs (`uid_map`), so it runs
//! *before* the Landlock ruleset locks the filesystem down.

use landlock::{
    Access, AccessFs, PathBeneath, PathFd, Ruleset, RulesetAttr, RulesetCreatedAttr, ABI,
};

use crate::policy::{Access as GrantAccess, Network, Policy};
use crate::ConfineError;

/// Apply [`policy`] to the current process. Single-threaded only.
pub fn apply(policy: &Policy) -> Result<(), ConfineError> {
    // 1. Network — before the filesystem lock, since `local` writes to procfs.
    match policy.network {
        Network::All => {}
        Network::None => net::deny_inet_sockets()?,
        Network::Local => net::enter_loopback_namespace()?,
    }

    // 2. Filesystem — Landlock ruleset, applied last and inherited across exec.
    apply_landlock(policy)
}

/// The device nodes every program assumes it can open for writing, whatever
/// the policy grants: the null device and the terminal. Landlock gates
/// `open(O_WRONLY)` on devices like any file, so without these `git` (which
/// opens `/dev/null` read-write on every command) fails before it starts.
const DEVICE_BASELINE: [&str; 4] = ["/dev/null", "/dev/tty", "/dev/ptmx", "/dev/pts"];

fn apply_landlock(policy: &Policy) -> Result<(), ConfineError> {
    // ABI v1 is the floor (read/write rights); this is the flat degradation
    // point the design commits to.
    let abi = ABI::V1;
    let read_only = AccessFs::from_read(abi);
    let read_write = AccessFs::from_all(abi);

    let mut ruleset = Ruleset::default()
        .handle_access(AccessFs::from_all(abi))
        .and_then(|r| r.create())
        .map_err(|e| ConfineError::ApplyFailed(format!("landlock create: {e}")))?;

    // A device node missing on this host is simply skipped, like a grant.
    for device in DEVICE_BASELINE {
        let Ok(fd) = PathFd::new(device) else {
            continue;
        };
        ruleset = ruleset
            .add_rule(PathBeneath::new(
                fd,
                AccessFs::ReadFile | AccessFs::WriteFile,
            ))
            .map_err(|e| ConfineError::ApplyFailed(format!("landlock add_rule: {e}")))?;
    }

    for grant in &policy.grants {
        // A grant on a path that does not exist is simply skipped
        let Ok(fd) = PathFd::new(&grant.path) else {
            continue;
        };
        let access = match grant.access {
            GrantAccess::Read => read_only,
            GrantAccess::ReadWrite => read_write,
            // List-only: the entries of a decomposed parent are visible (`ls`
            // works) but their contents are not readable.
            GrantAccess::ListDir => AccessFs::ReadDir.into(),
        };
        ruleset = ruleset
            .add_rule(PathBeneath::new(fd, access))
            .map_err(|e| ConfineError::ApplyFailed(format!("landlock add_rule: {e}")))?;
    }

    ruleset
        .restrict_self()
        .map_err(|e| ConfineError::ApplyFailed(format!("landlock restrict_self: {e}")))?;
    Ok(())
}

/// The confining network tiers.
mod net {
    use std::io::Write;
    use std::mem;

    use crate::ConfineError;

    /// `none`: a seccomp-BPF filter that fails `socket()` for the internet and
    /// packet families with `EPERM`, leaving `AF_UNIX` (and everything else)
    /// alone. `EPERM`, never a kill, so a probe adapts instead of dying.
    pub fn deny_inet_sockets() -> Result<(), ConfineError> {
        let prog = build_filter();
        unsafe {
            if libc::prctl(libc::PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0 {
                return Err(ConfineError::ApplyFailed("prctl(NO_NEW_PRIVS)".into()));
            }
            let fprog = libc::sock_fprog {
                len: prog.len() as u16,
                filter: prog.as_ptr() as *mut libc::sock_filter,
            };
            if libc::prctl(
                libc::PR_SET_SECCOMP,
                libc::SECCOMP_MODE_FILTER as libc::c_ulong,
                &fprog as *const _ as libc::c_ulong,
                0,
                0,
            ) != 0
            {
                return Err(ConfineError::ApplyFailed("prctl(SET_SECCOMP)".into()));
            }
        }
        Ok(())
    }

    // BPF opcodes and seccomp return actions.
    const LD_W_ABS: u16 = 0x20; // BPF_LD | BPF_W | BPF_ABS
    const JEQ_K: u16 = 0x15; // BPF_JMP | BPF_JEQ | BPF_K
    const RET_K: u16 = 0x06; // BPF_RET | BPF_K
    const RET_ALLOW: u32 = 0x7fff_0000; // SECCOMP_RET_ALLOW
    const RET_EPERM: u32 = 0x0005_0000 | (libc::EPERM as u32); // SECCOMP_RET_ERRNO | EPERM
    const RET_KILL: u32 = 0x8000_0000; // SECCOMP_RET_KILL_PROCESS

    // Offsets into `struct seccomp_data`.
    const OFF_NR: u32 = 0;
    const OFF_ARCH: u32 = 4;
    const OFF_ARG0: u32 = 16;

    #[cfg(target_arch = "x86_64")]
    const AUDIT_ARCH: u32 = 0xC000_003E;
    #[cfg(target_arch = "aarch64")]
    const AUDIT_ARCH: u32 = 0xC00000B7;

    const AF_INET: u32 = 2;
    const AF_INET6: u32 = 10;
    const AF_PACKET: u32 = 17;

    fn stmt(code: u16, k: u32) -> libc::sock_filter {
        libc::sock_filter {
            code,
            jt: 0,
            jf: 0,
            k,
        }
    }
    fn jump(code: u16, k: u32, jt: u8, jf: u8) -> libc::sock_filter {
        libc::sock_filter { code, jt, jf, k }
    }

    // Guard the arch (syscall numbers differ per ABI), then: if the syscall is
    // `socket` with AF_INET/AF_INET6/AF_PACKET -> EPERM; otherwise allow.
    fn build_filter() -> [libc::sock_filter; 12] {
        let nr_socket = libc::SYS_socket as u32;
        [
            stmt(LD_W_ABS, OFF_ARCH),      // 0: A = arch
            jump(JEQ_K, AUDIT_ARCH, 1, 0), // 1: arch ok -> +1, else kill
            stmt(RET_K, RET_KILL),         // 2: wrong arch -> kill
            stmt(LD_W_ABS, OFF_NR),        // 3: A = nr
            jump(JEQ_K, nr_socket, 0, 6),  // 4: socket? no -> allow(11)
            stmt(LD_W_ABS, OFF_ARG0),      // 5: A = domain (args[0] low)
            jump(JEQ_K, AF_INET, 3, 0),    // 6: -> EPERM(10)
            jump(JEQ_K, AF_INET6, 2, 0),   // 7: -> EPERM(10)
            jump(JEQ_K, AF_PACKET, 1, 0),  // 8: -> EPERM(10)
            stmt(RET_K, RET_ALLOW),        // 9: other domain -> allow
            stmt(RET_K, RET_EPERM),        // 10: inet/packet -> EPERM
            stmt(RET_K, RET_ALLOW),        // 11: non-socket -> allow
        ]
    }

    /// `local`: an unprivileged user+network namespace with only `lo` (brought
    /// up). Loopback works; everything off-box is unreachable by construction
    /// (an empty netns has no route).
    pub fn enter_loopback_namespace() -> Result<(), ConfineError> {
        let (uid, gid) = unsafe { (libc::getuid(), libc::getgid()) };
        unsafe {
            if libc::unshare(libc::CLONE_NEWUSER | libc::CLONE_NEWNET) != 0 {
                return Err(ConfineError::ApplyFailed("unshare(NEWUSER|NEWNET)".into()));
            }
        }
        // Map our own uid/gid to root inside the userns so we hold CAP_NET_ADMIN
        // there and can bring `lo` up.
        write_proc("/proc/self/setgroups", b"deny")?;
        write_proc("/proc/self/uid_map", format!("0 {uid} 1").as_bytes())?;
        write_proc("/proc/self/gid_map", format!("0 {gid} 1").as_bytes())?;
        bring_lo_up()
    }

    fn write_proc(path: &str, bytes: &[u8]) -> Result<(), ConfineError> {
        let mut f = std::fs::OpenOptions::new()
            .write(true)
            .open(path)
            .map_err(|e| ConfineError::ApplyFailed(format!("open {path}: {e}")))?;
        f.write_all(bytes)
            .map_err(|e| ConfineError::ApplyFailed(format!("write {path}: {e}")))
    }

    fn bring_lo_up() -> Result<(), ConfineError> {
        const SIOCGIFFLAGS: libc::c_ulong = 0x8913;
        const SIOCSIFFLAGS: libc::c_ulong = 0x8914;
        #[repr(C)]
        struct Ifreq {
            name: [u8; 16],
            flags: libc::c_short,
            _pad: [u8; 22],
        }
        unsafe {
            let s = libc::socket(libc::AF_INET, libc::SOCK_DGRAM, 0);
            if s < 0 {
                return Err(ConfineError::ApplyFailed("socket for lo".into()));
            }
            let mut req: Ifreq = mem::zeroed();
            req.name[..2].copy_from_slice(b"lo");
            let ok = libc::ioctl(s, SIOCGIFFLAGS, &mut req) == 0 && {
                req.flags |= (libc::IFF_UP | libc::IFF_RUNNING) as libc::c_short;
                libc::ioctl(s, SIOCSIFFLAGS, &req) == 0
            };
            libc::close(s);
            if ok {
                Ok(())
            } else {
                Err(ConfineError::ApplyFailed("bring lo up".into()))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::policy::{Grant, Network, Policy};
    use std::io::Read;
    use std::os::unix::io::FromRawFd;

    // Landlock availability at v1+, so tests can skip on old kernels rather than
    // fail. Creating a ruleset proves support without restricting.
    fn landlock_available() -> bool {
        Ruleset::default()
            .handle_access(AccessFs::from_all(ABI::V1))
            .and_then(|r| r.create())
            .is_ok()
    }

    // Run `body` in a forked child, returning its one-byte verdict (1 = pass).
    fn in_child(body: impl FnOnce() -> u8) -> u8 {
        let mut fds = [0i32; 2];
        unsafe { libc::pipe(fds.as_mut_ptr()) };
        let (r, w) = (fds[0], fds[1]);
        let pid = unsafe { libc::fork() };
        if pid == 0 {
            unsafe { libc::close(r) };
            let v = body();
            unsafe {
                libc::write(w, &v as *const u8 as *const _, 1);
                libc::_exit(0)
            };
        }
        unsafe { libc::close(w) };
        let mut f = unsafe { std::fs::File::from_raw_fd(r) };
        let mut b = [0u8; 1];
        let _ = f.read_exact(&mut b);
        let mut st = 0;
        unsafe { libc::waitpid(pid, &mut st, 0) };
        b[0]
    }

    #[test]
    fn list_dir_grant_lists_but_hides_contents() {
        if !landlock_available() {
            eprintln!("skip: no landlock");
            return;
        }
        let dir = std::env::temp_dir().join(format!("bestie_guard_{}", std::process::id()));
        std::fs::create_dir_all(dir.join("sub")).unwrap();
        std::fs::write(dir.join("sub/secret"), b"SECRET").unwrap();
        std::fs::write(dir.join("visible"), b"OK").unwrap();

        let dir_s = dir.to_str().unwrap().to_owned();
        let policy = Policy {
            grants: vec![
                Grant {
                    path: dir_s.clone(),
                    access: GrantAccess::ListDir,
                },
                Grant {
                    path: format!("{dir_s}/visible"),
                    access: GrantAccess::Read,
                },
            ],
            network: Network::All,
            ..Policy::default()
        };

        let verdict = in_child(move || {
            if apply(&policy).is_err() {
                return 0;
            }
            let lists = std::fs::read_dir(&dir).map(|r| r.count()).unwrap_or(0) > 0;
            let visible_ok = std::fs::read(dir.join("visible")).is_ok();
            let secret_denied = std::fs::read(dir.join("sub/secret")).is_err();
            u8::from(lists && visible_ok && secret_denied)
        });
        assert_eq!(verdict, 1, "ls works, visible reads, secret denied");
    }

    #[test]
    fn null_device_opens_for_writing_under_an_empty_policy() {
        if !landlock_available() {
            eprintln!("skip: no landlock");
            return;
        }
        let verdict = in_child(|| {
            if apply(&Policy {
                network: Network::All,
                ..Policy::default()
            })
            .is_err()
            {
                return 0;
            }
            let writable = std::fs::OpenOptions::new()
                .read(true)
                .write(true)
                .open("/dev/null")
                .is_ok();
            let etc_denied = std::fs::read("/etc/hostname").is_err();
            u8::from(writable && etc_denied)
        });
        assert_eq!(verdict, 1, "/dev/null opens read-write, nothing else does");
    }

    #[test]
    fn local_tier_isolates_to_own_loopback() {
        let verdict = in_child(|| {
            // Skip (pass) where unprivileged userns is unavailable (e.g. stock
            // Ubuntu) — the Dart adapter degrades this tier there.
            if net::enter_loopback_namespace().is_err() {
                return 1;
            }
            unsafe {
                // bind+listen+connect entirely on our own lo.
                let srv = libc::socket(libc::AF_INET, libc::SOCK_STREAM, 0);
                let mut sa: libc::sockaddr_in = std::mem::zeroed();
                sa.sin_family = libc::AF_INET as u16;
                sa.sin_addr.s_addr = u32::from_be_bytes([127, 0, 0, 1]).to_be();
                let sl = std::mem::size_of::<libc::sockaddr_in>() as u32;
                if libc::bind(srv, &sa as *const _ as *const libc::sockaddr, sl) != 0 {
                    return 0;
                }
                libc::listen(srv, 1);
                let mut got: libc::sockaddr_in = std::mem::zeroed();
                let mut gl = sl;
                libc::getsockname(srv, &mut got as *mut _ as *mut libc::sockaddr, &mut gl);
                let cli = libc::socket(libc::AF_INET, libc::SOCK_STREAM, 0);
                let loopback_ok =
                    libc::connect(cli, &got as *const _ as *const libc::sockaddr, sl) == 0;
                libc::close(cli);
                libc::close(srv);

                // Off-box is unreachable by construction (empty netns, no route).
                let ext = libc::socket(libc::AF_INET, libc::SOCK_STREAM, 0);
                let mut e: libc::sockaddr_in = std::mem::zeroed();
                e.sin_family = libc::AF_INET as u16;
                e.sin_port = 443u16.to_be();
                e.sin_addr.s_addr = u32::from_be_bytes([1, 1, 1, 1]).to_be();
                let ext_blocked =
                    libc::connect(ext, &e as *const _ as *const libc::sockaddr, sl) != 0;
                libc::close(ext);

                u8::from(loopback_ok && ext_blocked)
            }
        });
        assert_eq!(
            verdict, 1,
            "loopback works inside the netns, off-box blocked"
        );
    }

    #[test]
    fn none_tier_blocks_inet_but_not_unix() {
        let verdict = in_child(|| {
            if net::deny_inet_sockets().is_err() {
                return 0;
            }
            let inet = unsafe { libc::socket(libc::AF_INET, libc::SOCK_STREAM, 0) };
            let inet_blocked = inet < 0;
            if inet >= 0 {
                unsafe { libc::close(inet) };
            }
            let unix = unsafe { libc::socket(libc::AF_UNIX, libc::SOCK_STREAM, 0) };
            let unix_ok = unix >= 0;
            if unix >= 0 {
                unsafe { libc::close(unix) };
            }
            u8::from(inet_blocked && unix_ok)
        });
        assert_eq!(verdict, 1, "AF_INET blocked, AF_UNIX allowed");
    }
}
