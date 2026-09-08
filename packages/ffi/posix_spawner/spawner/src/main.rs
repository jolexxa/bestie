//! Supervised PTY / piped spawn helper for bestie's posix_dart.
//!
//! Invoked by bestie via `posix_spawn`. Two modes:
//!
//! ```text
//! spawner terminal <status_fd> <slave_path> [--confine-fd <N>] -- <target> [args...]
//! spawner piped    <status_fd> <stdin_read_fd> <stdout_write_fd> <stderr_write_fd> [--confine-fd <N>] -- <target> [args...]
//! ```
//!
//! We `fork()`: the child sets up its stdio (a controlling pty, or the
//! three handed-in pipe ends) and `execvp`s the target; the parent
//! stays alive as a *supervisor*. Because the target is now a
//! grandchild of the Dart VM, the VM's own SIGCHLD reaper cannot claim
//! it.
//!
//! When `--confine-fd <N>` is given, the child reads a NUL-delimited grant
//! program off fd `N` and confines itself just before `exec` — after stdio is
//! set up, so opening the pty slave is not itself denied. Confinement is
//! inherited across `exec`, so every descendant stays jailed. Absent the flag,
//! the child behaves exactly as before.

use std::env;
use std::ffi::CString;
use std::os::raw::{c_char, c_int};

// Pre-exec setup failures (raised in the forked child, forwarded to
// Dart as the target's wait-status).
const EXIT_BAD_ARGS: i32 = 100;
const EXIT_SETSID: i32 = 101;
const EXIT_OPEN_SLAVE: i32 = 102;
const EXIT_TIOCSCTTY: i32 = 103;
const EXIT_TCSETATTR: i32 = 104;
const EXIT_DUP2: i32 = 105;
const EXIT_EXEC: i32 = 106;
// `fork()` itself failed: no supervisor, no target. The helper exits
// without writing any frame, so Dart sees status-pipe EOF (<8 bytes)
// and reports supervisorLost.
const EXIT_FORK: i32 = 107;
// The confine program was malformed, wrong-version, or could not be
// applied. A confinement request that cannot be honoured must never
// degrade into an *unconfined* exec — it fails closed here.
const EXIT_SANDBOX_UNAVAIL: i32 = 108;

// Magic + wire version prefixing the grant program. A mismatch fails closed.
const WIRE_MAGIC: &[u8] = b"sandbox/1";

enum Mode {
    Terminal {
        slave_path: String,
    },
    Piped {
        stdin_read_fd: c_int,
        stdout_write_fd: c_int,
        stderr_write_fd: c_int,
    },
}

struct Invocation {
    status_fd: c_int,
    mode: Mode,
    confine_fd: Option<c_int>,
    target: Vec<String>,
}

fn main() {
    let args: Vec<String> = env::args().collect();
    match parse(&args) {
        Some(inv) => run(inv),
        None => {
            eprintln!(
                "spawner: usage:\n  \
                 spawner terminal <status_fd> <slave_path> [--confine-fd <N>] -- <target> [args...]\n  \
                 spawner piped <status_fd> <stdin_read_fd> <stdout_write_fd> \
                 <stderr_write_fd> [--confine-fd <N>] -- <target> [args...]"
            );
            unsafe { libc::_exit(EXIT_BAD_ARGS) };
        }
    }
}

/// Split argv at the first `--`: everything before is helper args,
/// everything after is the target's argv (which may itself contain
/// `--`). Returns `None` on any shape mismatch → usage error.
fn parse(args: &[String]) -> Option<Invocation> {
    let sep = args.iter().position(|a| a == "--")?;
    let target: Vec<String> = args.get(sep + 1..)?.to_vec();
    if target.is_empty() {
        return None;
    }
    let (confine_fd, head) = extract_confine_fd(&args[..sep])?;
    let head = head.as_slice();
    match head.get(1).map(String::as_str)? {
        "terminal" if head.len() == 4 => Some(Invocation {
            status_fd: head[2].parse().ok()?,
            mode: Mode::Terminal {
                slave_path: head[3].clone(),
            },
            confine_fd,
            target,
        }),
        "piped" if head.len() == 6 => Some(Invocation {
            status_fd: head[2].parse().ok()?,
            mode: Mode::Piped {
                stdin_read_fd: head[3].parse().ok()?,
                stdout_write_fd: head[4].parse().ok()?,
                stderr_write_fd: head[5].parse().ok()?,
            },
            confine_fd,
            target,
        }),
        _ => None,
    }
}

/// Pulls an optional `--confine-fd <N>` out of the head, returning the fd and
/// the head with those two tokens removed so the mode's arity check is
/// unaffected. `None` if the flag is present but its value is missing or
/// unparseable — a malformed confinement request is a usage error, never a
/// silently-unconfined spawn.
fn extract_confine_fd(head: &[String]) -> Option<(Option<c_int>, Vec<String>)> {
    match head.iter().position(|a| a == "--confine-fd") {
        None => Some((None, head.to_vec())),
        Some(pos) => {
            let fd = head.get(pos + 1)?.parse().ok()?;
            let mut rest = head[..pos].to_vec();
            rest.extend_from_slice(&head[pos + 2..]);
            Some((Some(fd), rest))
        }
    }
}

fn run(inv: Invocation) {
    let Invocation {
        status_fd,
        mode,
        confine_fd,
        target,
    } = inv;

    let pid = unsafe { libc::fork() };
    if pid < 0 {
        unsafe { libc::_exit(EXIT_FORK) };
    }
    if pid == 0 {
        child(status_fd, confine_fd, &mode, &target);
    }
    if let Some(fd) = confine_fd {
        // The child owns the confine program; the supervisor never reads it.
        unsafe { libc::close(fd) };
    }
    supervise(status_fd, pid, &mode);
}

/// Runs in the forked child: set up stdio for [mode], then `execvp` the
/// target. Never returns.
fn child(status_fd: c_int, confine_fd: Option<c_int>, mode: &Mode, target: &[String]) -> ! {
    // The supervisor owns the status pipe. The target must not keep a
    // write-end copy, or Dart never sees EOF after the two frames.
    unsafe { libc::close(status_fd) };

    // New session so the target is a session/pgrp leader (and, in
    // terminal mode, can claim the pty as its controlling tty).
    if unsafe { libc::setsid() } < 0 {
        unsafe { libc::_exit(EXIT_SETSID) };
    }

    match mode {
        Mode::Terminal { slave_path } => setup_terminal(slave_path),
        Mode::Piped {
            stdin_read_fd,
            stdout_write_fd,
            stderr_write_fd,
        } => setup_piped(*stdin_read_fd, *stdout_write_fd, *stderr_write_fd),
    }

    // Confine last: stdio is already wired, so the jail cannot deny opening the
    // pty slave, and it is inherited across the `exec` below.
    if let Some(fd) = confine_fd {
        confine(fd);
    }

    exec(target)
}

/// Read the grant program off [confine_fd] and confine the current process.
///
/// Any failure — malformed payload, wrong version, or a backend that cannot
/// apply it — exits `EXIT_SANDBOX_UNAVAIL` rather than `exec`ing unconfined.
fn confine(confine_fd: c_int) {
    // A read that could not complete must fail closed.
    let Some(program) = read_all(confine_fd) else {
        unsafe { libc::_exit(EXIT_SANDBOX_UNAVAIL) };
    };
    unsafe { libc::close(confine_fd) };

    if !wire_is_valid(&program) {
        unsafe { libc::_exit(EXIT_SANDBOX_UNAVAIL) };
    }

    // Fails closed: a jail that cannot be applied exits here rather than
    // exec'ing unconfined. We are single-threaded post-fork, so bestie_guard's
    // allocation is safe.
    if bestie_guard::confine(&program).is_err() {
        unsafe { libc::_exit(EXIT_SANDBOX_UNAVAIL) };
    }
}

/// Read [fd] to EOF. The confine program is a few hundred grants (~12 KB),
/// under the default pipe buffer, and bestie writes it after the spawn returns.
fn read_all(fd: c_int) -> Option<Vec<u8>> {
    let mut buf = Vec::new();
    let mut chunk = [0u8; 4096];
    loop {
        let n = unsafe { libc::read(fd, chunk.as_mut_ptr() as *mut libc::c_void, chunk.len()) };
        if n > 0 {
            buf.extend_from_slice(&chunk[..n as usize]);
        } else if n == 0 {
            return Some(buf);
        } else if std::io::Error::last_os_error().raw_os_error() == Some(libc::EINTR) {
            continue;
        } else {
            return None;
        }
    }
}

/// Whether [program]'s first NUL-delimited field is the expected magic.
fn wire_is_valid(program: &[u8]) -> bool {
    program.split(|&b| b == 0).next() == Some(WIRE_MAGIC)
}

/// Open the pty slave as the controlling tty and wire it to 0/1/2.
fn setup_terminal(slave_path: &str) {
    // Opening a tty in a session leader without `O_NOCTTY` can make it
    // our ctty implicitly; the explicit `TIOCSCTTY` below makes it
    // deterministic.
    let slave_path_c = CString::new(slave_path).unwrap();
    let slave_fd = unsafe { libc::open(slave_path_c.as_ptr(), libc::O_RDWR | libc::O_NOCTTY) };
    if slave_fd < 0 {
        unsafe { libc::_exit(EXIT_OPEN_SLAVE) };
    }

    // Explicit controlling-tty claim. `TIOCSCTTY` sets `tp->t_session`
    // AND `tp->t_pgrp` on macOS (xnu's tty.c), so subsequent ^C bytes
    // on the master deliver SIGINT to us.
    if unsafe { libc::ioctl(slave_fd, libc::TIOCSCTTY as _, 0 as c_int) } < 0 {
        unsafe { libc::_exit(EXIT_TIOCSCTTY) };
    }

    // Stamp known-good cooked-mode termios. The previous tenant of this
    // kernel pty slot may have left raw-mode flags behind; without
    // resetting, `^C` echoes as a literal `^C` instead of SIGINT.
    if !set_sane_termios(slave_fd) {
        unsafe { libc::_exit(EXIT_TCSETATTR) };
    }

    for target in [libc::STDIN_FILENO, libc::STDOUT_FILENO, libc::STDERR_FILENO] {
        if unsafe { libc::dup2(slave_fd, target) } < 0 {
            unsafe { libc::_exit(EXIT_DUP2) };
        }
    }
    if slave_fd > 2 {
        unsafe { libc::close(slave_fd) };
    }
}

/// Wire the three handed-in pipe ends to 0/1/2 and drop the originals,
/// so the target inherits only stdin/stdout/stderr.
fn setup_piped(stdin_read_fd: c_int, stdout_write_fd: c_int, stderr_write_fd: c_int) {
    let pairs = [
        (stdin_read_fd, libc::STDIN_FILENO),
        (stdout_write_fd, libc::STDOUT_FILENO),
        (stderr_write_fd, libc::STDERR_FILENO),
    ];
    for (src, dst) in pairs {
        if unsafe { libc::dup2(src, dst) } < 0 {
            unsafe { libc::_exit(EXIT_DUP2) };
        }
    }
    for src in [stdin_read_fd, stdout_write_fd, stderr_write_fd] {
        if src > 2 {
            unsafe { libc::close(src) };
        }
    }
}

/// Build argv and `execvp`. Passes the environment through unchanged
/// from whatever `posix_spawn` handed us. Never returns on success.
fn exec(target: &[String]) -> ! {
    let exec_target_c = CString::new(target[0].as_str()).unwrap();
    let arg_cstrings: Vec<CString> = target
        .iter()
        .map(|s| CString::new(s.as_str()).unwrap())
        .collect();
    let mut argv_raw: Vec<*const c_char> = arg_cstrings.iter().map(|c| c.as_ptr()).collect();
    argv_raw.push(std::ptr::null());

    unsafe {
        libc::execvp(exec_target_c.as_ptr(), argv_raw.as_ptr());
        // execvp returned → it failed.
        libc::_exit(EXIT_EXEC);
    }
}

/// Runs in the parent after `fork`: reaps the target and reports its
/// pid + raw wait-status down the status pipe. Never returns.
fn supervise(status_fd: c_int, child_pid: i32, mode: &Mode) -> ! {
    // Drop our copies of the child-only pipe ends. Critically, closing
    // the stdout/stderr write ends here means that when the target
    // exits, those pipes see *all* write ends gone → Dart's read loop
    // gets EOF. (Terminal mode hands us no such fds — the child opens
    // the slave from a path.)
    if let Mode::Piped {
        stdin_read_fd,
        stdout_write_fd,
        stderr_write_fd,
    } = mode
    {
        for fd in [*stdin_read_fd, *stdout_write_fd, *stderr_write_fd] {
            if fd > 2 {
                unsafe { libc::close(fd) };
            }
        }
    }

    write_frame(status_fd, child_pid);

    let mut status: c_int = 0;
    loop {
        let r = unsafe { libc::waitpid(child_pid, &mut status, 0) };
        if r >= 0 {
            break;
        }
        if std::io::Error::last_os_error().raw_os_error() != Some(libc::EINTR) {
            break;
        }
    }

    write_frame(status_fd, status);
    unsafe {
        libc::close(status_fd);
        libc::_exit(0);
    }
}

/// Write a 4-byte native-endian frame, retrying short writes and
/// `EINTR`. Gives up silently on any other error — Dart then sees a
/// short/absent frame and reports supervisorLost.
fn write_frame(fd: c_int, value: i32) {
    let bytes = value.to_ne_bytes();
    let mut written = 0usize;
    while written < bytes.len() {
        let n = unsafe {
            libc::write(
                fd,
                bytes[written..].as_ptr() as *const libc::c_void,
                bytes.len() - written,
            )
        };
        if n > 0 {
            written += n as usize;
        } else if n < 0 && std::io::Error::last_os_error().raw_os_error() == Some(libc::EINTR) {
            continue;
        } else {
            return;
        }
    }
}

/// Apply `stty sane`-equivalent termios defaults to the slave fd.
/// We do tcgetattr first so any platform-specific bits we don't
/// care about are preserved.
fn set_sane_termios(fd: c_int) -> bool {
    let mut t: libc::termios = unsafe { std::mem::zeroed() };
    if unsafe { libc::tcgetattr(fd, &mut t) } < 0 {
        return false;
    }

    // Input flags — cooked input with CR→NL translation, software
    // flow control, BRKINT, BEL on full buffer, UTF-8 input.
    t.c_iflag = libc::BRKINT | libc::ICRNL | libc::IXON | libc::IMAXBEL | libc::IUTF8;

    // Output flags — post-process, NL→CR-NL.
    t.c_oflag = libc::OPOST | libc::ONLCR;

    // Line discipline — SIGINT/SIGQUIT/SIGTSTP from control chars,
    // canonical line editing, echo typed chars + visible erase.
    t.c_lflag = libc::ISIG
        | libc::ICANON
        | libc::IEXTEN
        | libc::ECHO
        | libc::ECHOE
        | libc::ECHOK
        | libc::ECHOKE
        | libc::ECHOCTL
        | libc::PENDIN;

    // Control — preserve whatever the kernel set, then guarantee
    // 8-bit chars, receiver enabled, hangup on close.
    t.c_cflag |= libc::CREAD | libc::CS8 | libc::HUPCL;

    // Special control chars — `stty sane`.
    t.c_cc[libc::VINTR as usize] = 0x03; // ^C
    t.c_cc[libc::VQUIT as usize] = 0x1C; // ^\
    t.c_cc[libc::VERASE as usize] = 0x7F; // DEL
    t.c_cc[libc::VKILL as usize] = 0x15; // ^U
    t.c_cc[libc::VEOF as usize] = 0x04; // ^D
    t.c_cc[libc::VEOL as usize] = 0x00; // disabled
    t.c_cc[libc::VSTART as usize] = 0x11; // ^Q
    t.c_cc[libc::VSTOP as usize] = 0x13; // ^S
    t.c_cc[libc::VSUSP as usize] = 0x1A; // ^Z
    t.c_cc[libc::VREPRINT as usize] = 0x12; // ^R
    t.c_cc[libc::VWERASE as usize] = 0x17; // ^W
    t.c_cc[libc::VLNEXT as usize] = 0x16; // ^V
    t.c_cc[libc::VDISCARD as usize] = 0x0F; // ^O
    t.c_cc[libc::VMIN as usize] = 1;
    t.c_cc[libc::VTIME as usize] = 0;

    unsafe { libc::tcsetattr(fd, libc::TCSANOW, &t) >= 0 }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn argv(parts: &[&str]) -> Vec<String> {
        parts.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn terminal_without_confine_fd() {
        let inv = parse(&argv(&[
            "spawner",
            "terminal",
            "3",
            "/dev/ttys001",
            "--",
            "brush",
        ]))
        .expect("valid");
        assert_eq!(inv.status_fd, 3);
        assert!(inv.confine_fd.is_none());
        assert_eq!(inv.target, argv(&["brush"]));
        assert!(matches!(inv.mode, Mode::Terminal { .. }));
    }

    #[test]
    fn terminal_with_confine_fd() {
        let inv = parse(&argv(&[
            "spawner",
            "terminal",
            "3",
            "/dev/ttys001",
            "--confine-fd",
            "7",
            "--",
            "brush",
            "-lc",
            "ls",
        ]))
        .expect("valid");
        assert_eq!(inv.confine_fd, Some(7));
        assert_eq!(inv.status_fd, 3);
        assert_eq!(inv.target, argv(&["brush", "-lc", "ls"]));
        assert!(matches!(inv.mode, Mode::Terminal { .. }));
    }

    #[test]
    fn piped_with_confine_fd() {
        let inv = parse(&argv(&[
            "spawner",
            "piped",
            "3",
            "4",
            "5",
            "6",
            "--confine-fd",
            "9",
            "--",
            "brush",
        ]))
        .expect("valid");
        assert_eq!(inv.confine_fd, Some(9));
        assert!(matches!(inv.mode, Mode::Piped { .. }));
    }

    #[test]
    fn confine_fd_missing_value_is_usage_error() {
        assert!(parse(&argv(&[
            "spawner",
            "terminal",
            "3",
            "/dev/ttys001",
            "--confine-fd",
            "--",
            "brush",
        ]))
        .is_none());
    }

    #[test]
    fn wire_magic_gates_confinement() {
        assert!(wire_is_valid(b"sandbox/1\0all\0"));
        assert!(!wire_is_valid(b"sandbox/2\0all\0"));
        assert!(!wire_is_valid(b"garbage"));
    }
}
