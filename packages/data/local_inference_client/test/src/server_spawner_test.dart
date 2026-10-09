import 'dart:io';

import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_client/src/server_spawner.dart';
import 'package:test/test.dart';

void main() {
  const spawner = DetachedServerSpawner();

  test('starts a detached process', () async {
    final spawned = await spawner.spawn(Platform.resolvedExecutable, [
      '--version',
    ]);

    expect((spawned as ServerSpawned).pid, isPositive);
  });

  test('reports an executable that cannot be started', () async {
    final spawned = await spawner.spawn('/nowhere/bestie_server', []);

    expect(
      (spawned as ServerSpawnRefused).reason,
      endsWith('(/nowhere/bestie_server)'),
    );
  });
}
