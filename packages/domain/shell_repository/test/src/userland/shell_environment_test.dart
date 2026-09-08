import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';

void main() {
  const userland = ShellUserland(
    binDir: r'C:\cow\shell\bin',
    shellPath: r'C:\cow\shell\bin\brush.exe',
    executables: ShellExecutables.windows,
  );
  const posixUserland = ShellUserland(
    binDir: '/opt/bestie/shell/bin',
    shellPath: '/opt/bestie/shell/bin/brush',
    executables: ShellExecutables.posix,
  );
  const homeDir = r'C:\Users\cow';

  ShellEnvironment environmentOf(
    ShellUserland shell,
    Map<String, String> base,
  ) => ShellEnvironment(
    userland: shell,
    hostEnvironment: base,
    homeDir: homeDir,
  );

  Map<String, String> userEnv(ShellUserland shell, Map<String, String> base) =>
      environmentOf(shell, base).forUserShell();

  Map<String, String> agentEnv([Map<String, String> base = const {}]) =>
      environmentOf(userland, base).forAgentShell();

  group('the environment as a whole', () {
    test('carries the rest of the host environment through untouched', () {
      // What comes back is the child's entire environment, so anything not
      // deliberately replaced has to survive — nothing downstream merges the
      // host's back in.
      final result = userEnv(userland, {
        'CARGO_HOME': r'D:\cargo',
        'NVM_DIR': r'D:\nvm',
      });

      expect(result['CARGO_HOME'], r'D:\cargo');
      expect(result['NVM_DIR'], r'D:\nvm');
    });

    test('withholds the MSYS markers rather than overriding them', () {
      // Scripts branch on whether these are set at all to take MSYS
      // path-translation rules the shell bestie ships does not implement, so
      // the answer has to be "unset", not "set to something else".
      final result = userEnv(userland, {
        'MSYSTEM': 'MINGW64',
        'MINGW_PREFIX': '/mingw64',
        'EXEPATH': r'C:\Program Files\Git',
      });

      expect(result.containsKey('MSYSTEM'), isFalse);
      expect(result.containsKey('MINGW_PREFIX'), isFalse);
      expect(result.containsKey('EXEPATH'), isFalse);
    });

    test('withholds every copy that userland took of the host settings', () {
      final result = userEnv(userland, {
        'ORIGINAL_PATH': '/mingw64/bin:/usr/bin',
        'ORIGINAL_TMP': 'C:/Users/cow/AppData/Local/Temp',
        'ORIGINAL_TEMP': 'C:/Users/cow/AppData/Local/Temp',
      });

      expect(result.containsKey('ORIGINAL_PATH'), isFalse);
      expect(result.containsKey('ORIGINAL_TMP'), isFalse);
      expect(result.containsKey('ORIGINAL_TEMP'), isFalse);
    });

    test('withholds what that userland aimed at itself', () {
      // These point into the MSYS tree the shipped bin just displaced, and
      // TMPDIR names a POSIX path only that tree can resolve.
      final result = userEnv(userland, {
        'MSYSTEM': 'MINGW64',
        'MANPATH': r'C:\Program Files\Git\usr\share\man',
        'PKG_CONFIG_PATH': r'C:\Program Files\Git\mingw64\lib\pkgconfig',
        'CONFIG_SITE': 'C:/Program Files/Git/etc/config.site',
        'TMPDIR': '/tmp',
      });

      expect(result.containsKey('MANPATH'), isFalse);
      expect(result.containsKey('PKG_CONFIG_PATH'), isFalse);
      expect(result.containsKey('CONFIG_SITE'), isFalse);
      expect(result.containsKey('TMPDIR'), isFalse);
    });

    test('leaves those alone on a host that never announced that userland', () {
      // A POSIX host sets the same names for its own reasons, and there the
      // shell bestie ships can resolve every one of them.
      final result = userEnv(posixUserland, {
        'MANPATH': '/usr/local/share/man',
        'PKG_CONFIG_PATH': '/usr/local/lib/pkgconfig',
        'TMPDIR': '/tmp',
      });

      expect(result['MANPATH'], '/usr/local/share/man');
      expect(result['PKG_CONFIG_PATH'], '/usr/local/lib/pkgconfig');
      expect(result['TMPDIR'], '/tmp');
    });

    test('withholds the prompt the launching shell built for itself', () {
      // Git Bash exports a PS1 that calls `__git_ps1`, a function defined by
      // a profile script it re-sources on every startup. The shell bestie ships
      // reads the prompt but never that script, so it renders a
      // command-not-found where the branch name belongs.
      final result = userEnv(userland, {
        'PS1': r'\u@\h \w`__git_ps1`\n$ ',
        'PS2': '> ',
        'MSYS2_PS1': r'\u@\h \w`__git_ps1`\n$ ',
        'PROMPT_COMMAND': 'history -a',
      });

      expect(result.containsKey('PS1'), isFalse);
      expect(result.containsKey('PS2'), isFalse);
      expect(result.containsKey('MSYS2_PS1'), isFalse);
      // bestie sets its own PROMPT_COMMAND to defend the prompt, so the host's
      // is replaced rather than merely dropped.
      expect(result['PROMPT_COMMAND'], isNot(contains('history -a')));
    });

    test('withholds the startup file the launching shell was told to read', () {
      final result = userEnv(userland, {
        'BASH_ENV': r'C:\Users\cow\.bashenv',
        'ENV': r'C:\Users\cow\.shinit',
      });

      expect(result.containsKey('BASH_ENV'), isFalse);
      expect(result.containsKey('ENV'), isFalse);
    });

    test('withholds the option state the launching shell was set to', () {
      final result = userEnv(userland, {
        'SHELLOPTS': 'braceexpand:hashall',
        'BASHOPTS': 'checkwinsize:cmdhist',
      });

      expect(result.containsKey('SHELLOPTS'), isFalse);
      expect(result.containsKey('BASHOPTS'), isFalse);
    });

    test('withholds all of that from an agent shell too', () {
      final result = agentEnv({'PS1': '`__git_ps1`', 'BASH_ENV': '/x'});

      expect(result.containsKey('PS1'), isFalse);
      expect(result.containsKey('BASH_ENV'), isFalse);
    });

    test('does not mutate the base it was handed', () {
      final base = {'MSYSTEM': 'MINGW64', 'PATH': r'C:\Windows'};

      userEnv(userland, base);

      expect(base['MSYSTEM'], 'MINGW64');
      expect(base['PATH'], r'C:\Windows');
    });
  });

  group('the userland every shell runs out of', () {
    test('searches the shipped bin before anything installed', () {
      // Without this the eighty-odd bundled coreutils are shadowed by
      // whatever the host has, which is the dependency we are removing.
      final result = userEnv(userland, {
        'PATH': r'C:\Program Files\Git\usr\bin',
      });

      expect(result['PATH'], r'C:\cow\shell\bin;C:\Program Files\Git\usr\bin');
    });

    test('separates PATH entries the way the platform does', () {
      final result = userEnv(posixUserland, {'PATH': '/usr/bin'});

      expect(result['PATH'], '/opt/bestie/shell/bin:/usr/bin');
    });

    test('is just the userland when the host has no PATH at all', () {
      expect(userEnv(userland, const {})['PATH'], r'C:\cow\shell\bin');
    });

    test('reads the Windows spelling of PATH when that is what is set', () {
      final result = userEnv(userland, {'Path': r'C:\Windows'});

      expect(result['PATH'], r'C:\cow\shell\bin;C:\Windows');
    });

    test('leaves the host spelling behind rather than beside its own', () {
      // Windows environment blocks are case-insensitive, so shipping both
      // `Path` and `PATH` leaves it to chance which one the child resolves —
      // and the host's spelling is the one without the shipped bin on it.
      final result = userEnv(userland, {'Path': r'C:\Windows'});

      expect(result.keys.where((key) => key.toLowerCase() == 'path'), ['PATH']);
    });

    test('replaces the host spelling of every variable it sets', () {
      final result = userEnv(userland, {
        'Home': r'D:\elsewhere',
        'Shell': r'C:\Program Files\Git\bin\bash.exe',
        'Term': 'dumb',
      });

      expect(result.containsKey('Shell'), isFalse);
      expect(result['SHELL'], r'C:\cow\shell\bin\brush.exe');
      expect(result.containsKey('Home'), isFalse);
      expect(result.containsKey('Term'), isFalse);
    });

    test('names the shell bestie ships, not the one the host set', () {
      // Subshell escapes — vim's `:sh`, less's `!` — spawn $SHELL.
      final result = userEnv(userland, {
        'SHELL': r'C:\Program Files\Git\bin\bash.exe',
      });

      expect(result['SHELL'], r'C:\cow\shell\bin\brush.exe');
    });

    test('fills in a HOME when the host has none', () {
      // Windows does not persist HOME; Git Bash injects it. Launched from
      // PowerShell or Explorer the shell would otherwise have no `~`.
      expect(userEnv(userland, const {})['HOME'], homeDir);
    });

    test('leaves the user their own HOME when they have one', () {
      final result = userEnv(userland, {'HOME': r'D:\elsewhere'});

      expect(result['HOME'], r'D:\elsewhere');
    });

    test('treats an empty HOME as none at all', () {
      expect(userEnv(userland, {'HOME': ''})['HOME'], homeDir);
    });

    test(
      'advertises what the screen can render when the host said nothing',
      () {
        expect(userEnv(userland, const {})['TERM'], 'xterm-256color');
        expect(agentEnv()['TERM'], 'xterm-256color');
      },
    );

    test('keeps the host TERM when it has one', () {
      final result = userEnv(userland, {'TERM': 'screen-256color'});

      expect(result['TERM'], 'screen-256color');
    });

    test('treats an empty TERM as none at all', () {
      expect(userEnv(userland, {'TERM': ''})['TERM'], 'xterm-256color');
    });

    test('says a colour per cell is renderable, whatever the host said', () {
      // The child draws into bestie's own screen, which keeps 24 bits a cell.
      // What the terminal bestie was launched from can show only decides how
      // that screen is drawn afterwards.
      final result = userEnv(userland, {'COLORTERM': ''});

      expect(result['COLORTERM'], 'truecolor');
      expect(agentEnv()['COLORTERM'], 'truecolor');
    });
  });

  group('the prompt', () {
    String promptOf(Map<String, String> base) {
      final command = userEnv(userland, base)['PROMPT_COMMAND']!;
      return command.substring("PS1='".length, command.length - 1);
    }

    test('is bestie own, not whatever the host was wearing', () {
      expect(promptOf({'PS1': r'\u@\h\$ '}), isNot(r'\u@\h\$ '));
    });

    test('spends its first line on the path and its second on the cursor', () {
      // The pane is usually a narrow split beside the chat, so the path gets
      // a line to itself rather than the room left over on one.
      final prompt = promptOf(const {});

      expect(prompt, contains(r'\w'));
      expect(prompt, contains(r'\n'));
      expect(prompt.indexOf(r'\w'), lessThan(prompt.indexOf(r'\n')));
    });

    test('measures at its printed width, so reflow lands where it looks', () {
      // Colour left outside \[ \] is counted as though it took columns, and
      // every wrap and resize afterwards is off by that much.
      final prompt = promptOf(const {});
      final escapes = RegExp(r'\\e\[[0-9;]*m').allMatches(prompt);

      expect(escapes, isNotEmpty);
      for (final escape in escapes) {
        final before = prompt.substring(0, escape.start);
        expect(
          before.lastIndexOf(r'\['),
          greaterThan(before.lastIndexOf(r'\]')),
          reason: 'colour at ${escape.start} is not marked non-printing',
        );
      }
    });

    test('names the branch only inside a repository', () {
      // Bare `$b` would leave a separator dangling everywhere else.
      expect(promptOf(const {}), contains(r'${b:+ $b}'));
    });

    test('reasserts itself after a host startup file overwrites it', () {
      final command = userEnv(userland, {
        'PS1': r'\u@\h\$ ',
      })['PROMPT_COMMAND']!;

      expect(command, startsWith('PS1='));
      expect(command, contains('🥺'));
    });
  });

  group('a shell the user drives', () {
    test('is left to prompt and page as the user configured', () {
      final result = userEnv(userland, const {});

      expect(result.containsKey('PAGER'), isFalse);
      expect(result.containsKey('GIT_EDITOR'), isFalse);
    });

    test('signs commits as the user configured, since they are vouching', () {
      final result = userEnv(userland, const {});

      expect(result.containsKey('GIT_CONFIG_COUNT'), isFalse);
    });

    test('can still raise a credential dialog, since someone is watching', () {
      final result = userEnv(userland, {
        'SSH_ASKPASS': r'C:\Program Files\Git\mingw64\bin\git-askpass.exe',
      });

      expect(
        result['SSH_ASKPASS'],
        r'C:\Program Files\Git\mingw64\bin\git-askpass.exe',
      );
      expect(result.containsKey('SSH_ASKPASS_REQUIRE'), isFalse);
    });
  });

  group('a shell an agent drives', () {
    test('runs out of the same userland', () {
      final result = agentEnv({'PATH': r'C:\Windows'});

      expect(result['PATH'], r'C:\cow\shell\bin;C:\Windows');
      expect(result['SHELL'], r'C:\cow\shell\bin\brush.exe');
    });

    test('defeats every pager, the worst hazard of the lot', () {
      // On a tty `git log`, `systemctl status` and `man` all pipe to less,
      // which takes the alt screen and waits for a `q` nobody will press.
      final result = agentEnv();

      expect(result['PAGER'], 'cat');
      expect(result['GIT_PAGER'], 'cat');
      expect(result['SYSTEMD_PAGER'], 'cat');
    });

    test('turns prompts into failures it can read', () {
      final result = agentEnv();

      expect(result['GIT_TERMINAL_PROMPT'], '0');
      expect(result['DEBIAN_FRONTEND'], 'noninteractive');
    });

    test('aborts editor-invoking commands rather than succeeding empty', () {
      // `false`, not `true`: `true` exits zero, which reads as "saved
      // unchanged" and lets `git rebase -i` run the whole todo list.
      final result = agentEnv();

      expect(result['EDITOR'], 'false');
      expect(result['VISUAL'], 'false');
      expect(result['GIT_EDITOR'], 'false');
    });

    test('leaves its size in the tty, where a resize can still change it', () {
      // The user watches this shell and can resize it, so a size copied into
      // the environment would go stale — and tools that prefer it to
      // TIOCGWINSZ would believe the stale copy over the reflowed screen.
      final result = agentEnv();

      expect(result.containsKey('COLUMNS'), isFalse);
      expect(result.containsKey('LINES'), isFalse);
    });

    test('does not claim CI, which would cost colour everywhere', () {
      expect(agentEnv().containsKey('CI'), isFalse);
    });

    test('commits and tags unsigned, since no person is vouching', () {
      // Layered through the environment so it wins over the user's global
      // config without touching it, and never needs the keyring.
      final result = agentEnv();

      expect(result['GIT_CONFIG_COUNT'], '2');
      expect(result['GIT_CONFIG_KEY_0'], 'commit.gpgsign');
      expect(result['GIT_CONFIG_VALUE_0'], 'false');
      expect(result['GIT_CONFIG_KEY_1'], 'tag.gpgSign');
      expect(result['GIT_CONFIG_VALUE_1'], 'false');
    });

    test('layers after any git config the host already carried', () {
      final result = agentEnv({
        'GIT_CONFIG_COUNT': '1',
        'GIT_CONFIG_KEY_0': 'user.name',
        'GIT_CONFIG_VALUE_0': 'cow',
      });

      expect(result['GIT_CONFIG_COUNT'], '3');
      expect(result['GIT_CONFIG_KEY_0'], 'user.name');
      expect(result['GIT_CONFIG_VALUE_0'], 'cow');
      expect(result['GIT_CONFIG_KEY_1'], 'commit.gpgsign');
      expect(result['GIT_CONFIG_KEY_2'], 'tag.gpgSign');
    });

    test('cannot reach for a credential dialog nobody will answer', () {
      // GIT_TERMINAL_PROMPT covers the terminal, not the askpass helper, and
      // Git for Windows ships one that opens a window. An agent that hits a
      // private remote would wait on it forever with nothing on screen.
      final result = agentEnv({
        'SSH_ASKPASS': r'C:\Program Files\Git\mingw64\bin\git-askpass.exe',
        'GIT_ASKPASS': r'C:\Program Files\Git\mingw64\bin\git-askpass.exe',
      });

      expect(result.containsKey('SSH_ASKPASS'), isFalse);
      expect(result.containsKey('GIT_ASKPASS'), isFalse);
      expect(result['SSH_ASKPASS_REQUIRE'], 'never');
    });
  });
}
