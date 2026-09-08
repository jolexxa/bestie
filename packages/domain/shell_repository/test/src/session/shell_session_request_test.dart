import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:process_host/process_host.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';

void main() {
  const environment = ShellEnvironment(
    userland: ShellUserland(
      binDir: '/opt/bestie/bin',
      shellPath: '/opt/bestie/bin/brush',
      executables: ShellExecutables.posix,
    ),
    hostEnvironment: {'MSYSTEM': 'MINGW64', 'CARGO_HOME': '/home/cow/.cargo'},
    homeDir: '/home/cow',
  );

  ShellSessionRequest userShell({int rows = 24, int cols = 80}) =>
      ShellSessionRequest.userShell(
        environment: environment,
        rows: rows,
        cols: cols,
        scrollbackBytes: 10000 * 4096,
      );

  ShellSessionRequest agentShell({String command = 'ls -la'}) =>
      ShellSessionRequest.agentShell(
        environment: environment,
        command: command,
        rows: 24,
        cols: 80,
        scrollbackBytes: 10000 * 4096,
      );

  group('userShell', () {
    test('runs the shell bestie ships, not one the caller named', () {
      // The caller names no executable at all — it comes from the userland,
      // so what runs and what `SHELL` advertises cannot disagree.
      expect(userShell().executable, environment.shellPath);
      expect(userShell().environment['SHELL'], environment.shellPath);
    });

    test('carries the whole environment, not a set of overrides', () {
      // Nothing downstream merges the host's back in, so the pass-through
      // and the withholding both have to have happened by now.
      final request = userShell();

      expect(request.environment['CARGO_HOME'], '/home/cow/.cargo');
      expect(request.environment.containsKey('MSYSTEM'), isFalse);
    });

    test('takes the size it was opened at', () {
      final request = userShell(rows: 40, cols: 120);

      expect(request.rows, 40);
      expect(request.cols, 120);
    });

    test('runs no command of its own, because the user types them', () {
      expect(userShell().arguments, isEmpty);
    });

    test('is interactive so ^C reaches the foreground command', () {
      expect(userShell().launchMode, ShellLaunchMode.interactive);
    });

    test('reads rc files but not the profile, which rewrites PATH', () {
      // The user's own shell config still applies. What does not is the host
      // profile: an MSYS one rejoins PATH with POSIX separators that a native
      // shell cannot split, and the bundled userland stops resolving.
      expect(userShell().launchMode.flags, ['-i']);
    });

    test('lets the page own sizing rather than the host terminal', () {
      expect(userShell().forwardHostResize, isFalse);
    });

    test('leaves the pager to the user own config', () {
      expect(userShell().environment.containsKey('PAGER'), isFalse);
    });
  });

  group('agentShell', () {
    test('runs the command through the shell', () {
      expect(agentShell().arguments, ['-c', 'ls -la']);
    });

    test('runs the same shell the user gets', () {
      expect(agentShell().executable, environment.shellPath);
      expect(agentShell().environment['SHELL'], environment.shellPath);
    });

    test('runs unattended, so nothing waits on a keyboard', () {
      final request = agentShell();

      expect(request.environment['PAGER'], 'cat');
      expect(request.environment['GIT_TERMINAL_PROMPT'], '0');
    });

    test('runs the environment bestie built, not the one a profile wants', () {
      // `brush -c 'cmd'`, with no -l. A login shell lets the host profile
      // rewrite PATH out from under the bundled userland — on Windows an
      // MSYS profile rejoins it with POSIX separators, and nothing resolves
      // after that, not even the coreutils bestie ships.
      expect(agentShell().launchMode, ShellLaunchMode.raw);
    });

    test('is not interactive, which keeps the tree in one process group', () {
      // Without -i the shell never calls tcsetpgrp per command, so
      // cancelling the whole command is a clean kill(-pid).
      expect(agentShell().launchMode.flags, isNot(contains('-i')));
      expect(agentShell().forwardHostResize, isFalse);
    });

    test('is sized and scrolled exactly like the user own shell', () {
      // Every shell bestie runs is a pane in the multiplexer. What drives one
      // changes how it is launched, never how much of it someone can read.
      final agent = agentShell();
      final user = userShell();

      expect(agent.rows, user.rows);
      expect(agent.cols, user.cols);
      expect(agent.scrollbackBytes, user.scrollbackBytes);
      expect(agent.forwardHostResize, user.forwardHostResize);
    });

    test('does not pin the size it started at into the environment', () {
      // The pane is resizable, so the tty stays the only place its size
      // lives — a copy in the environment would go stale on the first reflow.
      final request = agentShell();

      expect(request.environment.containsKey('COLUMNS'), isFalse);
      expect(request.environment.containsKey('LINES'), isFalse);
    });
  });
}
