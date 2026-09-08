import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';

/// Shell environment configuration for agent and user shells.
@model
class ShellEnvironment {
  /// [hostEnvironment] is what bestie itself was launched with.
  const ShellEnvironment({
    required this.userland,
    required this.hostEnvironment,
    required this.homeDir,
  });

  /// The userland the shell runs out of.
  final ShellUserland userland;

  /// The environment bestie was started with.
  final Map<String, String> hostEnvironment;

  /// Where `~` points when the host names no `HOME`.
  final String homeDir;

  /// The shell every session runs.
  String get shellPath => userland.shellPath;

  /// `TERM` when the host set none.
  static const _defaultTerm = 'xterm-256color';

  /// The working directory, then the colour the branch is written in.
  static const _promptPath = r'\[\e[38;5;114m\]\w\[\e[0m\]\[\e[38;5;245m\]';

  /// The branch, and nothing at all outside a repository.
  static const _promptBranch =
      r'$(b=$(git branch --show-current 2>/dev/null); printf "%s" "${b:+ $b}")';

  /// Path and branch on one line, prompt on the next. Colours sit inside `\[`
  /// and `\]` so the shell measures the prompt at its printed width.
  static const _prompt = '$_promptPath$_promptBranch\\[\\e[0m\\]\\n🥺 ';

  /// Reasserts the prompt after every command, so a host startup file that
  /// overwrites `PS1` (like macOS `/etc/bashrc`) never gets the last word.
  static const _promptCommand = "PS1='$_prompt'";

  /// Variables that announce an MSYS2 / MinGW userland.
  static const _msysMarkers = {
    'MSYSTEM',
    'MSYSTEM_PREFIX',
    'MSYSTEM_CHOST',
    'MINGW_PREFIX',
    'MINGW_CHOST',
    'MINGW_PACKAGE_PREFIX',
    'EXEPATH',
    'ORIGINAL_PATH',
    'ORIGINAL_TMP',
    'ORIGINAL_TEMP',
  };

  /// Variables an MSYS2 / MinGW userland aims at itself, each of which a
  /// POSIX host sets for its own unrelated reasons.
  static const _msysUserlandPointers = {
    'ACLOCAL_PATH',
    'MANPATH',
    'INFOPATH',
    'CONFIG_SITE',
    'TMPDIR',
    'PKG_CONFIG_PATH',
    'PKG_CONFIG_SYSTEM_INCLUDE_PATH',
    'PKG_CONFIG_SYSTEM_LIBRARY_PATH',
  };

  /// Variables routing a credential prompt to a window nobody is watching.
  static const _guiPrompts = {'SSH_ASKPASS', 'GIT_ASKPASS'};

  /// Variables holding the launching shell's own configuration.
  static const _parentShellState = {
    'PS0',
    'PS1',
    'PS2',
    'PS3',
    'PS4',
    'MSYS2_PS1',
    'PROMPT_COMMAND',
    'PROMPT_DIRTRIM',
    'BASH_ENV',
    'ENV',
    'SHELLOPTS',
    'BASHOPTS',
  };

  /// Overrides to disable paging, editor, but do not indicate CI.
  static const _unattended = {
    'PAGER': 'cat',
    'GIT_PAGER': 'cat',
    'SYSTEMD_PAGER': 'cat',
    'GIT_TERMINAL_PROMPT': '0',
    'DEBIAN_FRONTEND': 'noninteractive',
    'EDITOR': 'false',
    'VISUAL': 'false',
    'GIT_EDITOR': 'false',
    'SSH_ASKPASS_REQUIRE': 'never',
  };

  /// Git configuration an agent shell layers above the user's own files. A
  /// signature says a person vouched for the commit, which an unattended agent
  /// cannot, and signing would need the keyring the sandbox withholds anyway.
  static const _unsignedGit = {
    'commit.gpgsign': 'false',
    'tag.gpgSign': 'false',
  };

  /// The environment a shell the user drives runs in.
  Map<String, String> forUserShell() => _userland();

  /// The environment a shell an agent drives runs in.
  Map<String, String> forAgentShell() {
    final result = <String, String>{..._userland(), ..._unattended};
    _guiPrompts.forEach(result.remove);
    _layerGitConfig(result, _unsignedGit);
    return result;
  }

  /// Appends [entries] to the `GIT_CONFIG_COUNT` layer of [environment], after
  /// any the host already carries so none of the user's own are lost.
  static void _layerGitConfig(
    Map<String, String> environment,
    Map<String, String> entries,
  ) {
    var count = int.tryParse(environment['GIT_CONFIG_COUNT'] ?? '') ?? 0;
    for (final entry in entries.entries) {
      environment['GIT_CONFIG_KEY_$count'] = entry.key;
      environment['GIT_CONFIG_VALUE_$count'] = entry.value;
      count++;
    }
    environment['GIT_CONFIG_COUNT'] = '$count';
  }

  Map<String, String> _userland() {
    final base = hostEnvironment;
    final hostPath = base['PATH'] ?? base['Path'] ?? '';
    final overrides = <String, String>{
      'PATH': hostPath.isEmpty
          ? userland.binDir
          : '${userland.binDir}${userland.executables.pathSeparator}'
                '$hostPath',
      'SHELL': userland.shellPath,
      'PROMPT_COMMAND': _promptCommand,
      // The child draws into bestie's screen, which holds a color per cell, so
      // it should say what it can render there rather than what the terminal
      // bestie was launched from can.
      'COLORTERM': 'truecolor',
      if ((base['HOME'] ?? '').isEmpty) 'HOME': homeDir,
      if ((base['TERM'] ?? '').isEmpty) 'TERM': _defaultTerm,
    };
    // Windows spells it `Path`, and its environment blocks are
    // case-insensitive, so leaving the host's spelling in place would race
    // ours for the same variable.
    final replaced = overrides.keys.map((key) => key.toLowerCase()).toSet();
    final result = <String, String>{...base}
      ..removeWhere((key, _) => replaced.contains(key.toLowerCase()));
    _msysMarkers.forEach(result.remove);
    _parentShellState.forEach(result.remove);
    if (base.containsKey('MSYSTEM')) {
      _msysUserlandPointers.forEach(result.remove);
    }
    return result..addAll(overrides);
  }
}
