import 'dart:async';

import 'package:built_in_server_client/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockProcessHost extends Mock implements ProcessHost {}

class _MockRunningProcess extends Mock implements RunningProcess {}

void main() {
  const environment = {'HOME': '/home/joanna'};
  late _MockProcessHost host;
  late _MockRunningProcess process;
  late StreamController<List<int>> stdout;
  late StreamController<List<int>> stderr;
  late Completer<ProcessExit> exit;
  late SupervisedServerSpawner spawner;

  setUp(() {
    host = _MockProcessHost();
    process = _MockRunningProcess();
    stdout = StreamController<List<int>>();
    stderr = StreamController<List<int>>();
    exit = Completer<ProcessExit>();
    when(() => process.pid).thenAnswer((_) async => 42);
    when(() => process.stdout).thenAnswer((_) => stdout.stream);
    when(() => process.stderr).thenAnswer((_) => stderr.stream);
    when(() => process.exit).thenAnswer((_) => exit.future);
    when(process.close).thenAnswer((_) async {});
    when(
      () => host.piped(
        executable: any(named: 'executable'),
        arguments: any(named: 'arguments'),
        environment: any(named: 'environment'),
      ),
    ).thenReturn(ProcessSpawnSucceeded(process));
    spawner = SupervisedServerSpawner(host: host, environment: environment);
  });

  test('starts the server through pipes in the host environment', () async {
    final spawned = await spawner.spawn('bestie_server', ['--log', 'x']);

    expect((spawned as ServerSpawned).pid, 42);
    verify(
      () => host.piped(
        executable: 'bestie_server',
        arguments: ['--log', 'x'],
        environment: environment,
      ),
    ).called(1);
  });

  test('drains what the server writes so it never blocks', () async {
    await spawner.spawn('bestie_server', []);

    stdout.add([1, 2, 3]);
    stderr.add([4]);
    await pumpEventQueue();

    expect(stdout.hasListener, isTrue);
    expect(stderr.hasListener, isTrue);
  });

  test('tells how the server ended and lets the handle go', () async {
    final spawned = await spawner.spawn('bestie_server', []) as ServerSpawned;
    var ended = false;
    unawaited(spawned.exit.then((_) => ended = true));
    await pumpEventQueue();
    expect(ended, isFalse);
    verifyNever(process.close);

    exit.complete(const ProcessSignaled(11));

    expect(await spawned.exit, const ProcessSignaled(11));
    verify(process.close).called(1);
  });

  test('reports a server that could not be started', () async {
    when(
      () => host.piped(
        executable: any(named: 'executable'),
        arguments: any(named: 'arguments'),
        environment: any(named: 'environment'),
      ),
    ).thenReturn(
      const ProcessSpawnFailed(
        SpawnFailure(function: 'posix_spawnp', message: 'No such file'),
      ),
    );

    final spawned = await spawner.spawn('/nowhere/bestie_server', []);

    expect(
      (spawned as ServerSpawnRefused).reason,
      'No such file (/nowhere/bestie_server)',
    );
  });
}
