import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:built_in_server_client/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('launches a server for the bestie directory', () {
    const launch = BuiltInServerLaunch(
      command: ProgramCommand(executable: 'dart', arguments: ['run', 'server']),
      bestieDir: '/bestie',
      logFile: '/bestie/logs/server.log',
    );

    expect(launch.arguments, [
      'run',
      'server',
      '--bestie-dir',
      '/bestie',
      '--log',
      '/bestie/logs/server.log',
    ]);
  });

  test('compares load options by value', () {
    const capped = ModelLoadOptions(contextCap: 4096);

    expect(capped, const ModelLoadOptions(contextCap: 4096));
    expect(capped.hashCode, const ModelLoadOptions(contextCap: 4096).hashCode);
    expect(capped, isNot(ModelLoadOptions.defaults));
    expect(capped.toString(), 'ModelLoadOptions(contextCap: 4096)');
  });

  test('describes where this bestie stands with the server', () {
    const connections = <BuiltInServerConnection>[
      BuiltInServerDisconnected(reason: 'gone'),
      BuiltInServerAttaching(),
      BuiltInServerAttached(ownerToken: 'token', port: 4100),
      BuiltInServerBusy(ownerPid: 12),
      BuiltInServerVersionMismatch(protocolVersion: 2, serverVersion: '0.2.0'),
      BuiltInServerSpawnFailed(reason: 'missing'),
    ];

    expect(connections, hasLength(6));
  });

  test('carries what each server request found', () {
    const ready = ModelReady(
      localId: 'qwen',
      contextSize: 8192,
      maxAgents: 3,
      deviceBytes: 1,
    );
    const results = <Object>[
      ModelLoaded(ready),
      ModelLoadFailed('oom'),
      ModelUnloadSucceeded(),
      ModelUnloadFailed('down'),
      ServerSpawned(pid: 42),
      ServerSpawnRefused('missing'),
    ];

    expect(results, hasLength(6));
  });
}
