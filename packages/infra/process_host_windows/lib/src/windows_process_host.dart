import 'package:process_host/process_host.dart';
import 'package:process_host_windows/src/windows_host_winsize_source.dart';
import 'package:process_host_windows/src/windows_running_process.dart';
import 'package:process_host_windows/src/windows_sandbox.dart';
import 'package:win32_dart/win32_dart.dart';

/// Spawns children on Windows: a ConPTY pseudoconsole in [terminal] mode,
/// three inherited pipes in [piped] mode.
class WindowsProcessHost implements ProcessHost {
  /// [conptyLibraryPath] names the `conpty.dll` we ship beside its own
  /// console host.
  WindowsProcessHost({
    required String conptyLibraryPath,
    WindowsBindings? bindings,
    Pipes? pipes,
    PseudoConsoles? consoles,
    AttributeLists? attributeLists,
    ChildProcesses? children,
    this.readLoops = const ReadLoops(),
    this.exitWaiters = const ExitWaiters(),
    HostWinsizeSource winsizeSource = const WindowsHostWinsizeSource(),
    ConptyLibraries conptyLibraries = const ConptyLibraries(),
  }) : _bindings = bindings,
       _pipes = pipes ?? Pipes(bindings ?? win32),
       _consoles = consoles,
       _attributeLists = attributeLists ?? AttributeLists(bindings ?? win32),
       _children = children ?? ChildProcesses(bindings ?? win32),
       _winsizeSource = winsizeSource,
       _conptyLibraryPath = conptyLibraryPath,
       _conptyLibraries = conptyLibraries;

  // Resolved to the real host lazily, so a spawn with no sandbox never loads
  // the DLLs — mock-injected tests stay host-agnostic.
  final WindowsBindings? _bindings;
  final Pipes _pipes;
  final PseudoConsoles? _consoles;
  final AttributeLists _attributeLists;
  final ChildProcesses _children;
  final String _conptyLibraryPath;
  final ConptyLibraries _conptyLibraries;

  /// The console host, opened on the first spawn and kept: opening it twice
  /// would be wasted work, and failing twice would say the same thing twice.
  late final ConptyOpenResult _conpty = _conptyLibraries.open(
    _conptyLibraryPath,
  );

  /// Starts the isolate that drains a child's output.
  final ReadLoops readLoops;

  /// Starts the isolate that waits on a child's exit.
  final ExitWaiters exitWaiters;

  final HostWinsizeSource _winsizeSource;

  @override
  ProcessSpawnResult terminal({
    required Map<String, String> environment,
    String? executable,
    List<String> arguments = const [],
    int? initialRows,
    int? initialCols,
    ShellLaunchMode launchMode = ShellLaunchMode.login,
    bool forwardHostResize = true,
    covariant WindowsSandbox? sandbox,
  }) {
    final PseudoConsoles consoles;
    switch (_conpty) {
      case ConptyOpenFailed(:final reason):
        return ProcessSpawnFailed(
          SpawnFailure(
            function: 'CreatePseudoConsole',
            message:
                'The console host bestie ships could not be opened: $reason '
                'Run `dart tool/download_openconsole_assets.dart` from the '
                'repo root.',
          ),
        );
      case ConptyOpenSucceeded(:final conpty):
        consoles = _consoles ?? PseudoConsoles(conpty);
    }

    if (executable == null) return _missingExecutable;

    final host = _winsizeSource.current;
    final command = _commandLine(executable, [
      ...launchMode.flags,
      ...arguments,
    ]);

    final input = _openPipe();
    if (input == null) return _pipeFailure;
    final output = _openPipe();
    if (output == null) {
      input.close();
      return _pipeFailure;
    }

    final consoleResult = consoles.open(
      rows: initialRows ?? host.rows,
      cols: initialCols ?? host.cols,
      input: input.readEnd,
      output: output.writeEnd,
    );
    if (consoleResult case PseudoConsoleCreateFailed(:final failure)) {
      input.close();
      output.close();
      return ProcessSpawnFailed(_spawnFailureFrom(failure));
    }
    final console = (consoleResult as PseudoConsoleCreateSucceeded).console;

    final capabilities = _capabilitiesFor(sandbox);
    if (sandbox != null && capabilities == null) {
      console.close();
      input.close();
      output.close();
      return _capabilitiesFailure(sandbox);
    }

    final attributeResult = _attributeLists.build([
      ProcThreadAttribute.pseudoConsole(console),
      if (capabilities != null) capabilities.attribute,
    ]);
    if (attributeResult case AttributeListFailed(:final failure)) {
      capabilities?.close();
      console.close();
      input.close();
      output.close();
      return ProcessSpawnFailed(_spawnFailureFrom(failure));
    }
    final attributeList =
        (attributeResult as AttributeListSucceeded).attributeList;

    final childResult = _children.start(
      commandLine: command,
      attributeList: attributeList,
      environment: sandbox?.environmentFor(environment) ?? environment,
      workingDirectory: sandbox?.workingDirectory,
    );
    // The attribute list and its capabilities can be released once
    // CreateProcessW has consumed them.
    attributeList.close();
    capabilities?.close();

    if (childResult case ChildProcessStartFailed(:final failure)) {
      console.close();
      input.close();
      output.close();
      return ProcessSpawnFailed(_spawnFailureFrom(failure));
    }
    final child = (childResult as ChildProcessStartSucceeded).process;

    // Hand the pty-side ends to the pseudoconsole; keep our stdin write end
    // and stdout read end.
    input.closeReadEnd();
    output.closeWriteEnd();

    return ProcessSpawnSucceeded(
      WindowsRunningProcess.terminal(
        child: child,
        console: console,
        inputPipe: input,
        outputPipe: output,
        outputLoop: readLoops.start(output.readEnd),
        exitWaiter: exitWaiters.start(child.processHandle),
        sandbox: sandbox,
        hostResizeStream: forwardHostResize ? _winsizeSource.changes : null,
      ),
    );
  }

  @override
  ProcessSpawnResult piped({
    required Map<String, String> environment,
    String? executable,
    List<String> arguments = const [],
    ShellLaunchMode launchMode = ShellLaunchMode.raw,
    covariant WindowsSandbox? sandbox,
  }) {
    if (executable == null) return _missingExecutable;

    final command = _commandLine(executable, [
      ...launchMode.flags,
      ...arguments,
    ]);

    final pipes = <Pipe>[];
    Pipe? openInheritable() {
      final pipe = _openPipe(inheritable: true);
      if (pipe != null) pipes.add(pipe);
      return pipe;
    }

    final stdinPipe = openInheritable();
    final stdoutPipe = openInheritable();
    final stderrPipe = openInheritable();
    if (stdinPipe == null || stdoutPipe == null || stderrPipe == null) {
      for (final pipe in pipes) {
        pipe.close();
      }
      return _pipeFailure;
    }

    final capabilities = _capabilitiesFor(sandbox);
    if (sandbox != null && capabilities == null) {
      for (final pipe in pipes) {
        pipe.close();
      }
      return _capabilitiesFailure(sandbox);
    }

    // The child inherits exactly its three stdio ends and nothing else.
    final attributeResult = _attributeLists.build([
      ProcThreadAttribute.handleList([
        stdinPipe.readEnd,
        stdoutPipe.writeEnd,
        stderrPipe.writeEnd,
      ]),
      if (capabilities != null) capabilities.attribute,
    ]);
    if (attributeResult case AttributeListFailed(:final failure)) {
      capabilities?.close();
      for (final pipe in pipes) {
        pipe.close();
      }
      return ProcessSpawnFailed(_spawnFailureFrom(failure));
    }
    final attributeList =
        (attributeResult as AttributeListSucceeded).attributeList;

    final childResult = _children.start(
      commandLine: command,
      attributeList: attributeList,
      environment: sandbox?.environmentFor(environment) ?? environment,
      workingDirectory: sandbox?.workingDirectory,
      inheritHandles: true,
      stdInput: stdinPipe.readEnd,
      stdOutput: stdoutPipe.writeEnd,
      stdError: stderrPipe.writeEnd,
    );
    attributeList.close();
    capabilities?.close();

    if (childResult case ChildProcessStartFailed(:final failure)) {
      for (final pipe in pipes) {
        pipe.close();
      }
      return ProcessSpawnFailed(_spawnFailureFrom(failure));
    }
    final child = (childResult as ChildProcessStartSucceeded).process;

    // Once handed over, the child-side ends must close here so the read loops
    // see EOF when the child exits.
    stdinPipe.closeReadEnd();
    stdoutPipe.closeWriteEnd();
    stderrPipe.closeWriteEnd();

    return ProcessSpawnSucceeded(
      WindowsRunningProcess.piped(
        child: child,
        stdinPipe: stdinPipe,
        stdoutPipe: stdoutPipe,
        stderrPipe: stderrPipe,
        stdoutLoop: readLoops.start(stdoutPipe.readEnd),
        stderrLoop: readLoops.start(stderrPipe.readEnd),
        exitWaiter: exitWaiters.start(child.processHandle),
        sandbox: sandbox,
      ),
    );
  }

  /// Builds the `SECURITY_CAPABILITIES` attribute confining a child to
  /// [sandbox]'s AppContainer, or null when there is no [sandbox] *or* its SID
  /// strings cannot be parsed — the caller distinguishes the two and fails
  /// closed on the latter, never spawning unconfined.
  _AppliedCapabilities? _capabilitiesFor(WindowsSandbox? sandbox) =>
      sandbox == null
      ? null
      : _AppliedCapabilities.build(_bindings ?? win32, sandbox);

  static ProcessSpawnFailed _capabilitiesFailure(WindowsSandbox sandbox) =>
      ProcessSpawnFailed(
        SpawnFailure(
          function: 'SECURITY_CAPABILITIES',
          message:
              'Could not build AppContainer security capabilities from the '
              'container SID ${sandbox.containerSid}.',
        ),
      );

  Pipe? _openPipe({bool inheritable = false}) =>
      switch (_pipes.open(inheritable: inheritable)) {
        PipeOpenSucceeded(:final pipe) => pipe,
        PipeOpenFailed() => null,
      };

  static const _pipeFailure = ProcessSpawnFailed(
    SpawnFailure(function: 'CreatePipe', message: 'Could not create a pipe.'),
  );

  static const _missingExecutable = ProcessSpawnFailed(
    SpawnFailure(
      function: 'CreateProcessW',
      message: 'No executable was named for the child to run.',
    ),
  );

  static String _commandLine(String executable, List<String> arguments) =>
      [executable, ...arguments].map(_quoteArgument).join(' ');

  /// Quotes [argument] per the `CommandLineToArgvW` rules the CRT and MSYS
  /// both parse: wrap anything with whitespace or quotes, doubling the run of
  /// backslashes that precedes a quote (or the closing quote). Without this a
  /// `bash -c "script with spaces"` arrives split across argv.
  static String _quoteArgument(String argument) {
    if (argument.isNotEmpty && !argument.contains(RegExp('[ \t\n"]'))) {
      return argument;
    }
    final buffer = StringBuffer('"');
    var backslashes = 0;
    for (final unit in argument.codeUnits) {
      if (unit == 0x5c) {
        backslashes++;
      } else if (unit == 0x22) {
        buffer.write('\\' * (backslashes * 2 + 1));
        backslashes = 0;
        buffer.writeCharCode(unit);
      } else {
        if (backslashes > 0) {
          buffer.write('\\' * backslashes);
          backslashes = 0;
        }
        buffer.writeCharCode(unit);
      }
    }
    buffer.write('\\' * (backslashes * 2));
    return (buffer..write('"')).toString();
  }

  static SpawnFailure _spawnFailureFrom(Win32Failure failure) => SpawnFailure(
    function: failure.function,
    message: failure.message,
    code: failure.code,
  );
}

/// A `SECURITY_CAPABILITIES` attribute and the native memory behind it, freed
/// once `CreateProcessW` has consumed the attribute list.
class _AppliedCapabilities {
  _AppliedCapabilities._(this.attribute, this._capabilities, this._sids);

  /// Parses [sandbox]'s container and capability SIDs and packs them into a
  /// `SECURITY_CAPABILITIES` attribute. Null if any SID fails to parse.
  static _AppliedCapabilities? build(
    WindowsBindings bindings,
    WindowsSandbox sandbox,
  ) {
    final sids = Sids(bindings);
    final container = sids.fromString(sandbox.containerSid);
    if (container is! SidSucceeded) return null;

    final owned = <Sid>[container.sid];
    final capabilities = <Sid>[];
    for (final capability in sandbox.capabilitySids) {
      final parsed = sids.fromString(capability);
      if (parsed is! SidSucceeded) {
        for (final sid in owned) {
          sid.close();
        }
        return null;
      }
      owned.add(parsed.sid);
      capabilities.add(parsed.sid);
    }

    final caps = SecurityCapabilities.forContainer(
      container.sid,
      capabilities: capabilities,
    );
    return _AppliedCapabilities._(
      ProcThreadAttribute.securityCapabilities(caps),
      caps,
      owned,
    );
  }

  /// The attribute to hand `AttributeLists.build`.
  final ProcThreadAttribute attribute;

  final SecurityCapabilities _capabilities;
  final List<Sid> _sids;

  /// Frees the `SECURITY_CAPABILITIES` struct and the SIDs it named.
  void close() {
    _capabilities.close();
    for (final sid in _sids) {
      sid.close();
    }
  }
}
