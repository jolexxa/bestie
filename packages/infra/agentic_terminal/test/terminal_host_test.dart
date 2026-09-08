import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockProcessHost extends Mock implements ProcessHost {}

class _MockRunningProcess extends Mock implements RunningProcess {}

class _FakeSandbox implements Sandbox {}

const _failure = SpawnFailure(
  function: 'posix_spawnp',
  message: 'No such file or directory',
  code: 2,
);

void main() {
  setUpAll(() {
    registerFallbackValue(ShellLaunchMode.login);
    registerFallbackValue(<int>[]);
    registerFallbackValue(<String, String>{});
  });

  late _MockProcessHost processHost;
  late _MockRunningProcess process;
  late ProcessHostTerminalHost host;

  setUp(() {
    processHost = _MockProcessHost();
    process = _MockRunningProcess();
    host = ProcessHostTerminalHost(processHost);

    when(() => process.stdout).thenAnswer((_) => const Stream.empty());
    when(() => process.childRepaintsOnResize).thenReturn(false);
    when(() => process.writeBytes(any())).thenReturn(null);
  });

  void whenTerminalReturns(ProcessSpawnResult result) {
    when(
      () => processHost.terminal(
        executable: any(named: 'executable'),
        arguments: any(named: 'arguments'),
        environment: any(named: 'environment'),
        initialRows: any(named: 'initialRows'),
        initialCols: any(named: 'initialCols'),
        launchMode: any(named: 'launchMode'),
        forwardHostResize: any(named: 'forwardHostResize'),
        sandbox: any(named: 'sandbox'),
      ),
    ).thenReturn(result);
  }

  test('wraps a spawned process in a screen-backed terminal', () async {
    whenTerminalReturns(ProcessSpawnSucceeded(process));

    final result = await host.spawn(
      rows: 24,
      cols: 80,
      scrollbackBytes: 0 * 4096,
      environment: const {},
    );

    expect(result, isA<TerminalSpawnSucceeded>());
  });

  test('sizes the screen to match what the child was given', () async {
    whenTerminalReturns(ProcessSpawnSucceeded(process));

    final result = await host.spawn(
      scrollbackBytes: 0 * 4096,
      rows: 40,
      cols: 120,
      environment: const {},
    );

    final terminal = switch (result) {
      TerminalSpawnSucceeded(:final terminal) => terminal,
      TerminalSpawnFailed(:final failure) => fail('spawn failed: $failure'),
    };
    final snapshot = terminal.snapshot();
    expect(snapshot.rows, 40);
    expect(snapshot.cols, 120);

    verify(
      () => processHost.terminal(
        executable: any(named: 'executable'),
        arguments: any(named: 'arguments'),
        environment: any(named: 'environment'),
        initialRows: 40,
        initialCols: 120,
        launchMode: any(named: 'launchMode'),
        forwardHostResize: any(named: 'forwardHostResize'),
      ),
    ).called(1);
  });

  test('floors collapsed spawn dimensions at one cell', () async {
    whenTerminalReturns(ProcessSpawnSucceeded(process));

    await host.spawn(
      rows: 0,
      cols: 0,
      scrollbackBytes: 0,
      environment: const {},
    );

    verify(
      () => processHost.terminal(
        executable: any(named: 'executable'),
        arguments: any(named: 'arguments'),
        environment: any(named: 'environment'),
        initialRows: 1,
        initialCols: 1,
        launchMode: any(named: 'launchMode'),
        forwardHostResize: any(named: 'forwardHostResize'),
      ),
    ).called(1);
  });

  test('surfaces a refused spawn rather than throwing', () async {
    whenTerminalReturns(const ProcessSpawnFailed(_failure));

    final result = await host.spawn(
      rows: 24,
      cols: 80,
      scrollbackBytes: 0 * 4096,
      environment: const {},
    );

    expect(
      result,
      isA<TerminalSpawnFailed>().having((r) => r.failure, 'failure', _failure),
    );
  });

  test('creates no terminal when the spawn is refused', () async {
    whenTerminalReturns(const ProcessSpawnFailed(_failure));

    await host.spawn(
      rows: 24,
      cols: 80,
      scrollbackBytes: 0 * 4096,
      environment: const {},
    );

    verifyZeroInteractions(process);
  });

  test(
    'passes the caller launch options through to the process host',
    () async {
      whenTerminalReturns(ProcessSpawnSucceeded(process));

      await host.spawn(
        rows: 24,
        cols: 80,
        scrollbackBytes: 0 * 4096,
        executable: '/bin/sh',
        arguments: const ['-c', 'echo hi'],
        environment: const {'TERM': 'dumb'},
        launchMode: ShellLaunchMode.raw,
        forwardHostResize: false,
      );

      verify(
        () => processHost.terminal(
          executable: '/bin/sh',
          arguments: const ['-c', 'echo hi'],
          environment: const {'TERM': 'dumb'},
          initialRows: 24,
          initialCols: 80,
          launchMode: ShellLaunchMode.raw,
          forwardHostResize: false,
          sandbox: any(named: 'sandbox'),
        ),
      ).called(1);
    },
  );

  test('confines the child with the sandbox it was given', () async {
    whenTerminalReturns(ProcessSpawnSucceeded(process));
    final sandbox = _FakeSandbox();

    await host.spawn(
      rows: 24,
      cols: 80,
      scrollbackBytes: 0 * 4096,
      environment: const {},
      sandbox: sandbox,
    );

    verify(
      () => processHost.terminal(
        executable: any(named: 'executable'),
        arguments: any(named: 'arguments'),
        environment: any(named: 'environment'),
        initialRows: any(named: 'initialRows'),
        initialCols: any(named: 'initialCols'),
        launchMode: any(named: 'launchMode'),
        forwardHostResize: any(named: 'forwardHostResize'),
        sandbox: sandbox,
      ),
    ).called(1);
  });
}
