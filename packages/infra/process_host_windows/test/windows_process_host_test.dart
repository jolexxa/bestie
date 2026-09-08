import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_windows/process_host_windows.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

class _MockPipes extends Mock implements Pipes {}

class _MockConsoles extends Mock implements PseudoConsoles {}

class _MockConptyLibraries extends Mock implements ConptyLibraries {}

class _MockConpty extends Mock implements Conpty {}

class _MockAttributeLists extends Mock implements AttributeLists {}

class _MockChildren extends Mock implements ChildProcesses {}

class _MockReadLoops extends Mock implements ReadLoops {}

class _MockExitWaiters extends Mock implements ExitWaiters {}

class _MockWinsizeSource extends Mock implements HostWinsizeSource {}

class _MockPipe extends Mock implements Pipe {}

class _MockPseudoConsole extends Mock implements PseudoConsole {}

class _MockAttributeList extends Mock implements AttributeList {}

class _MockChildProcess extends Mock implements ChildProcess {}

class _MockReadLoop extends Mock implements WindowsReadLoop {}

class _MockExitWaiter extends Mock implements ProcessExitWaiter {}

class _FakeWindowsBindings extends Fake implements WindowsBindings {}

class _MockWindowsSandbox extends Mock implements WindowsSandbox {}

class _MockForeignSandbox extends Mock implements Sandbox {}

/// Never opened for real — every test injects the library or the consoles.
const _libraryPath = r'C:\cow\lib\conpty.dll';

const _failure = Win32Failure(
  function: 'CreateProcessW',
  code: 5,
  message: 'Access is denied.',
  channel: Win32ErrorChannel.lastError,
);

void main() {
  setUpAll(() {
    // Win32Handle is an extension type, so mocktail sees its representation.
    registerFallbackValue(Pointer<Void>.fromAddress(0));
    registerFallbackValue(<Win32Handle>[]);
    registerFallbackValue(<ProcThreadAttribute>[]);
    registerFallbackValue(_FakeWindowsBindings());
    registerFallbackValue(calloc<COORD>().ref);
    registerFallbackValue(_MockPseudoConsole());
    registerFallbackValue(_MockAttributeList());
    registerFallbackValue(_MockChildProcess());
  });

  late _MockPipes pipes;
  late _MockConsoles consoles;
  late _MockConptyLibraries libraries;
  late _MockConpty conpty;
  late _MockAttributeLists attributeLists;
  late _MockChildren children;
  late _MockReadLoops readLoops;
  late _MockExitWaiters exitWaiters;
  late _MockWinsizeSource winsizeSource;
  late List<_MockPipe> openedPipes;
  late List<PipeOpenResult> pipeResults;
  late _MockPseudoConsole console;
  late _MockAttributeList attributeList;
  late _MockChildProcess child;
  late StreamController<Winsize> hostSizes;

  /// A distinct handle per pipe end, so teardown can be pinned to the pipe it
  /// belongs to.
  Win32Handle handle(int address) =>
      Win32Handle(Pointer<Void>.fromAddress(address));

  setUp(() {
    pipes = _MockPipes();
    consoles = _MockConsoles();
    libraries = _MockConptyLibraries();
    conpty = _MockConpty();
    attributeLists = _MockAttributeLists();
    children = _MockChildren();
    readLoops = _MockReadLoops();
    exitWaiters = _MockExitWaiters();
    winsizeSource = _MockWinsizeSource();
    console = _MockPseudoConsole();
    attributeList = _MockAttributeList();
    child = _MockChildProcess();
    hostSizes = StreamController<Winsize>.broadcast();

    openedPipes = List.generate(3, (index) {
      final pipe = _MockPipe();
      when(() => pipe.readEnd).thenReturn(handle(0x10 + index * 2));
      when(() => pipe.writeEnd).thenReturn(handle(0x11 + index * 2));
      return pipe;
    });
    pipeResults = [for (final pipe in openedPipes) PipeOpenSucceeded(pipe)];

    when(() => child.processHandle).thenReturn(handle(0xA0));
    when(() => console.handle).thenReturn(Pointer<Void>.fromAddress(0x99));
    when(() => winsizeSource.current).thenReturn((rows: 24, cols: 80));
    when(() => winsizeSource.changes).thenAnswer((_) => hostSizes.stream);

    when(() => libraries.open(any())).thenReturn(ConptyOpenSucceeded(conpty));
    when(
      () => conpty.createPseudoConsole(any(), any(), any(), any(), any()),
    ).thenReturn(0);
    when(
      () => pipes.open(inheritable: any(named: 'inheritable')),
    ).thenAnswer((_) => pipeResults.removeAt(0));
    when(
      () => consoles.open(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
        input: any(named: 'input'),
        output: any(named: 'output'),
      ),
    ).thenReturn(PseudoConsoleCreateSucceeded(console));
    when(
      () => attributeLists.build(any()),
    ).thenReturn(AttributeListSucceeded(attributeList));
    when(
      () => children.start(
        commandLine: any(named: 'commandLine'),
        attributeList: any(named: 'attributeList'),
        environment: any(named: 'environment'),
        workingDirectory: any(named: 'workingDirectory'),
        inheritHandles: any(named: 'inheritHandles'),
        stdInput: any(named: 'stdInput'),
        stdOutput: any(named: 'stdOutput'),
        stdError: any(named: 'stdError'),
      ),
    ).thenReturn(ChildProcessStartSucceeded(child));
    when(() => readLoops.start(any())).thenReturn(_MockReadLoop());
    when(() => exitWaiters.start(any())).thenAnswer((_) {
      final waiter = _MockExitWaiter();
      when(() => waiter.exitCode).thenAnswer((_) => Completer<int?>().future);
      return waiter;
    });
  });

  tearDown(() async {
    await hostSizes.close();
  });

  WindowsProcessHost buildHost() => WindowsProcessHost(
    conptyLibraryPath: _libraryPath,
    conptyLibraries: libraries,
    pipes: pipes,
    consoles: consoles,
    attributeLists: attributeLists,
    children: children,
    readLoops: readLoops,
    exitWaiters: exitWaiters,
    winsizeSource: winsizeSource,
  );

  ProcessSpawnResult spawnTerminal({
    String? executable = r'C:\bin\sh.exe',
    List<String> arguments = const [],
    Map<String, String> environment = const {},
    int? initialRows,
    int? initialCols,
    bool forwardHostResize = false,
  }) => buildHost().terminal(
    executable: executable,
    arguments: arguments,
    environment: environment,
    launchMode: ShellLaunchMode.raw,
    initialRows: initialRows,
    initialCols: initialCols,
    forwardHostResize: forwardHostResize,
  );

  ProcessSpawnResult spawnPiped({
    String? executable = r'C:\bin\sh.exe',
    List<String> arguments = const [],
    Map<String, String> environment = const {},
  }) => buildHost().piped(
    executable: executable,
    arguments: arguments,
    environment: environment,
  );

  SpawnFailure failureOf(ProcessSpawnResult result) =>
      (result as ProcessSpawnFailed).failure;

  String commandLineOf(ProcessSpawnResult result) =>
      verify(
            () => children.start(
              commandLine: captureAny(named: 'commandLine'),
              attributeList: any(named: 'attributeList'),
              environment: any(named: 'environment'),
              inheritHandles: any(named: 'inheritHandles'),
              stdInput: any(named: 'stdInput'),
              stdOutput: any(named: 'stdOutput'),
              stdError: any(named: 'stdError'),
            ),
          ).captured.single
          as String;

  group('shell resolution', () {
    test('uses the requested executable as given', () {
      final result = spawnPiped(executable: r'C:\bin\sh.exe');

      expect(commandLineOf(result), r'C:\bin\sh.exe');
    });

    test('refuses a terminal spawn with no executable to run', () {
      // Windows has no system shell to fall back to, so there is nothing to
      // guess at — the caller names the shell bestie ships.
      expect(
        failureOf(spawnTerminal(executable: null)).message,
        contains('No'),
      );
    });

    test('refuses a piped spawn with no executable to run', () {
      expect(failureOf(spawnPiped(executable: null)).message, contains('No'));
    });

    test('adds login flags for a login shell', () {
      final host = buildHost();

      final result = host.piped(
        executable: r'C:\bin\sh.exe',
        environment: const {},
        launchMode: ShellLaunchMode.login,
      );

      expect(commandLineOf(result), r'C:\bin\sh.exe -l');
    });

    test('adds interactive flags on top for an interactive shell', () {
      final host = buildHost();

      final result = host.piped(
        executable: r'C:\bin\sh.exe',
        environment: const {},
        launchMode: ShellLaunchMode.interactiveLogin,
      );

      expect(commandLineOf(result), r'C:\bin\sh.exe -l -i');
    });
  });

  group('environment', () {
    Map<String, String> environmentGiven() =>
        verify(
              () => children.start(
                commandLine: any(named: 'commandLine'),
                attributeList: any(named: 'attributeList'),
                environment: captureAny(named: 'environment'),
                inheritHandles: any(named: 'inheritHandles'),
                stdInput: any(named: 'stdInput'),
                stdOutput: any(named: 'stdOutput'),
                stdError: any(named: 'stdError'),
              ),
            ).captured.single
            as Map<String, String>;

    test('hands the child exactly what the caller named, for a terminal', () {
      // Nothing is inherited or defaulted here — the caller decided, and a
      // name it left out has to stay out.
      spawnTerminal(environment: const {'PATH': r'C:\cow\bin'});

      expect(environmentGiven(), {'PATH': r'C:\cow\bin'});
    });

    test('hands the child exactly what the caller named, when piped', () {
      spawnPiped(environment: const {'PATH': r'C:\cow\bin'});

      expect(environmentGiven(), {'PATH': r'C:\cow\bin'});
    });
  });

  group('command line quoting', () {
    test('leaves a plain argument alone', () {
      expect(
        commandLineOf(spawnPiped(arguments: const ['-c'])),
        endsWith('-c'),
      );
    });

    test('wraps an argument containing spaces', () {
      final result = spawnPiped(arguments: const ['echo hi']);

      expect(commandLineOf(result), endsWith('"echo hi"'));
    });

    test('escapes embedded quotes so argv sees them', () {
      final result = spawnPiped(arguments: const ['say "hi"']);

      expect(commandLineOf(result), endsWith(r'"say \"hi\""'));
    });

    test('doubles the backslashes that precede a quote', () {
      // Otherwise CommandLineToArgvW reads the backslash as escaping the quote.
      final result = spawnPiped(arguments: const [r'a\"b']);

      expect(commandLineOf(result), endsWith(r'"a\\\"b"'));
    });

    test('doubles a trailing backslash run before the closing quote', () {
      final result = spawnPiped(arguments: const [r'C:\path with space\']);

      expect(commandLineOf(result), endsWith(r'"C:\path with space\\"'));
    });

    test('quotes an empty argument so it is not swallowed', () {
      expect(commandLineOf(spawnPiped(arguments: const [''])), endsWith('""'));
    });
  });

  group('the console host', () {
    ProcessSpawnResult spawn() =>
        WindowsProcessHost(
          conptyLibraryPath: _libraryPath,
          conptyLibraries: libraries,
          pipes: pipes,
          attributeLists: attributeLists,
          children: children,
          readLoops: readLoops,
          exitWaiters: exitWaiters,
          winsizeSource: winsizeSource,
        ).terminal(
          executable: r'C:\bin\sh.exe',
          environment: const {},
          launchMode: ShellLaunchMode.raw,
          forwardHostResize: false,
        );

    test('is the one bestie ships, never the one Windows came with', () {
      spawn();

      verify(() => libraries.open(_libraryPath)).called(1);
    });

    test('is opened once however many children are spawned', () {
      pipeResults.addAll([
        for (final pipe in openedPipes) PipeOpenSucceeded(pipe),
      ]);
      final host = WindowsProcessHost(
        conptyLibraryPath: _libraryPath,
        conptyLibraries: libraries,
        pipes: pipes,
        attributeLists: attributeLists,
        children: children,
        readLoops: readLoops,
        exitWaiters: exitWaiters,
        winsizeSource: winsizeSource,
      );

      host
        ..terminal(executable: r'C:\bin\sh.exe', environment: const {})
        ..terminal(executable: r'C:\bin\sh.exe', environment: const {});

      verify(() => libraries.open(any())).called(1);
    });

    // No fallback: a host that cannot be opened is a refused spawn, not a
    // quiet downgrade to the console Windows came with.
    test('refuses the spawn, and says why, when it cannot be opened', () {
      when(
        () => libraries.open(any()),
      ).thenReturn(const ConptyOpenFailed('exports nothing useful'));

      final failure = failureOf(spawn());

      expect(failure.function, 'CreatePseudoConsole');
      expect(failure.message, contains('exports nothing useful'));
      expect(failure.message, contains('download_openconsole_assets'));
    });
  });

  group('terminal', () {
    test('sizes the console to the host when no size is requested', () {
      spawnTerminal();

      verify(
        () => consoles.open(
          rows: 24,
          cols: 80,
          input: any(named: 'input'),
          output: any(named: 'output'),
        ),
      ).called(1);
    });

    test('prefers an explicitly requested size', () {
      spawnTerminal(initialRows: 40, initialCols: 120);

      verify(
        () => consoles.open(
          rows: 40,
          cols: 120,
          input: any(named: 'input'),
          output: any(named: 'output'),
        ),
      ).called(1);
    });

    test('hands the pty its own ends and keeps ours', () {
      spawnTerminal();

      // The console reads our input pipe and writes our output pipe, so the
      // ends it owns must not stay open on this side.
      verify(openedPipes[0].closeReadEnd).called(1);
      verify(openedPipes[1].closeWriteEnd).called(1);
      verifyNever(openedPipes[0].closeWriteEnd);
      verifyNever(openedPipes[1].closeReadEnd);
    });

    test('releases the attribute list once CreateProcessW has consumed it', () {
      spawnTerminal();

      verify(attributeList.close).called(1);
    });

    test('forwards host size changes when asked to', () async {
      final result = spawnTerminal(forwardHostResize: true);

      expect(result, isA<ProcessSpawnSucceeded>());
      verify(() => winsizeSource.changes).called(1);
    });

    test('leaves host size changes alone otherwise', () {
      spawnTerminal();

      verifyNever(() => winsizeSource.changes);
    });

    test('fails when the input pipe cannot be opened', () {
      pipeResults = [const PipeOpenFailed(_failure)];

      expect(failureOf(spawnTerminal()).function, 'CreatePipe');
    });

    test('closes the input pipe when the output pipe cannot be opened', () {
      pipeResults = [
        PipeOpenSucceeded(openedPipes[0]),
        const PipeOpenFailed(_failure),
      ];

      expect(failureOf(spawnTerminal()).function, 'CreatePipe');
      verify(openedPipes[0].close).called(1);
    });

    test('closes both pipes when the console cannot be created', () {
      when(
        () => consoles.open(
          rows: any(named: 'rows'),
          cols: any(named: 'cols'),
          input: any(named: 'input'),
          output: any(named: 'output'),
        ),
      ).thenReturn(const PseudoConsoleCreateFailed(_failure));

      final failure = failureOf(spawnTerminal());

      expect(failure.function, 'CreateProcessW');
      expect(failure.code, 5);
      verify(openedPipes[0].close).called(1);
      verify(openedPipes[1].close).called(1);
    });

    test('closes the console when the attribute list cannot be built', () {
      when(
        () => attributeLists.build(any()),
      ).thenReturn(const AttributeListFailed(_failure));

      expect(failureOf(spawnTerminal()).message, 'Access is denied.');
      verify(console.close).called(1);
      verify(openedPipes[0].close).called(1);
      verify(openedPipes[1].close).called(1);
    });

    test('closes the console when the child cannot start', () {
      when(
        () => children.start(
          commandLine: any(named: 'commandLine'),
          attributeList: any(named: 'attributeList'),
          environment: any(named: 'environment'),
          inheritHandles: any(named: 'inheritHandles'),
          stdInput: any(named: 'stdInput'),
          stdOutput: any(named: 'stdOutput'),
          stdError: any(named: 'stdError'),
        ),
      ).thenReturn(const ChildProcessStartFailed(_failure));

      expect(failureOf(spawnTerminal()).function, 'CreateProcessW');
      verify(console.close).called(1);
      verify(openedPipes[0].close).called(1);
      verify(openedPipes[1].close).called(1);
    });
  });

  group('piped', () {
    test('gives the child exactly its three stdio ends', () {
      // Read the ends up front: a mock call inside a verify closure is taken
      // for part of the matcher.
      final stdin = openedPipes[0].readEnd;
      final stdout = openedPipes[1].writeEnd;
      final stderr = openedPipes[2].writeEnd;

      spawnPiped();

      verify(
        () => children.start(
          commandLine: any(named: 'commandLine'),
          attributeList: any(named: 'attributeList'),
          environment: any(named: 'environment'),
          inheritHandles: true,
          stdInput: stdin,
          stdOutput: stdout,
          stdError: stderr,
        ),
      ).called(1);
      final attributes =
          verify(() => attributeLists.build(captureAny())).captured.single
              as List<ProcThreadAttribute>;
      expect(attributes.single.attribute, procThreadAttributeHandleList);
    });

    test('opens inheritable pipes, unlike the pty path', () {
      spawnPiped();

      verify(() => pipes.open(inheritable: true)).called(3);
    });

    test('closes the child-side ends so the read loops see EOF', () {
      spawnPiped();

      verify(openedPipes[0].closeReadEnd).called(1);
      verify(openedPipes[1].closeWriteEnd).called(1);
      verify(openedPipes[2].closeWriteEnd).called(1);
    });

    test('closes whatever opened when a later pipe fails', () {
      pipeResults = [
        PipeOpenSucceeded(openedPipes[0]),
        PipeOpenSucceeded(openedPipes[1]),
        const PipeOpenFailed(_failure),
      ];

      expect(failureOf(spawnPiped()).function, 'CreatePipe');
      verify(openedPipes[0].close).called(1);
      verify(openedPipes[1].close).called(1);
    });

    test('closes every pipe when the attribute list cannot be built', () {
      when(
        () => attributeLists.build(any()),
      ).thenReturn(const AttributeListFailed(_failure));

      expect(failureOf(spawnPiped()).code, 5);
      for (final pipe in openedPipes) {
        verify(pipe.close).called(1);
      }
    });

    test('closes every pipe when the child cannot start', () {
      when(
        () => children.start(
          commandLine: any(named: 'commandLine'),
          attributeList: any(named: 'attributeList'),
          environment: any(named: 'environment'),
          inheritHandles: any(named: 'inheritHandles'),
          stdInput: any(named: 'stdInput'),
          stdOutput: any(named: 'stdOutput'),
          stdError: any(named: 'stdError'),
        ),
      ).thenReturn(const ChildProcessStartFailed(_failure));

      expect(failureOf(spawnPiped()).function, 'CreateProcessW');
      for (final pipe in openedPipes) {
        verify(pipe.close).called(1);
      }
    });

    test('drains stdout and stderr separately', () {
      final stdout = openedPipes[1].readEnd;
      final stderr = openedPipes[2].readEnd;

      spawnPiped();

      verify(() => readLoops.start(stdout)).called(1);
      verify(() => readLoops.start(stderr)).called(1);
    });
  });

  group('sandbox', () {
    RunningProcess processOf(ProcessSpawnResult result) =>
        (result as ProcessSpawnSucceeded).process;

    _MockWindowsSandbox confinement() {
      final sandbox = _MockWindowsSandbox();
      when(() => sandbox.containerSid).thenReturn('S-1-15-2-1');
      when(() => sandbox.capabilitySids).thenReturn(const []);
      when(() => sandbox.workingDirectory).thenReturn(r'C:\work');
      when(() => sandbox.tempDir).thenReturn(r'C:\pkg\AC\Temp');
      return sandbox;
    }

    test(
      'a terminal child reports the confinement it was spawned in',
      () {
        final sandbox = confinement();

        final result = buildHost().terminal(
          executable: r'C:\bin\sh.exe',
          environment: const {},
          launchMode: ShellLaunchMode.raw,
          forwardHostResize: false,
          sandbox: sandbox,
        );

        expect(processOf(result).sandbox, same(sandbox));
      },
      // Building SECURITY_CAPABILITIES parses the SID through real win32.
      skip: Platform.isWindows ? null : 'exercises real win32 SID parsing',
    );

    test(
      'a piped child reports the confinement it was spawned in',
      () {
        final sandbox = confinement();

        final result = buildHost().piped(
          executable: r'C:\bin\sh.exe',
          environment: const {},
          sandbox: sandbox,
        );

        expect(processOf(result).sandbox, same(sandbox));
      },
      // Building SECURITY_CAPABILITIES parses the SID through real win32.
      skip: Platform.isWindows ? null : 'exercises real win32 SID parsing',
    );

    test('an unconfined child reports no confinement', () {
      expect(processOf(spawnPiped()).sandbox, isNull);
    });

    test('refuses a confinement of another platform', () {
      // Narrowing the parameter buys a runtime check in place of a
      // compile-time one: only a mismatched composition root gets here.
      final ProcessHost host = buildHost();

      expect(
        () => host.piped(
          executable: r'C:\bin\sh.exe',
          environment: const {},
          sandbox: _MockForeignSandbox(),
        ),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
