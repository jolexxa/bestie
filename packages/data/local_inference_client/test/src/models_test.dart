import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_client/src/models/server_results.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('launches a server for the bestie directory', () {
    const launch = LocalServerLaunch(
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

  test('describes where this bestie stands with the server', () {
    const connections = <LocalServerConnection>[
      LocalServerDisconnected(reason: 'gone'),
      LocalServerAttaching(),
      LocalServerAttached(ownerToken: 'token', port: 4100),
      LocalServerBusy(ownerPid: 12),
      LocalServerVersionMismatch(protocolVersion: 2, serverVersion: '0.2.0'),
      LocalServerSpawnFailed(reason: 'missing'),
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
