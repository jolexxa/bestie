import 'dart:io';

import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:built_in_server_client/src/server_spawner.dart';
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
